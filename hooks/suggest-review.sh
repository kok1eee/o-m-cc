#!/bin/bash
# Auto-trigger code review after phase completion + sync tasks.json for cc-sidebar
# PostToolUse (Write|Edit) で実行
# tasks.md のフェーズ完了を検知して code-reviewer 実行を指示
# ~/.claude-monitor/tasks.json にタスク状態を書き出し

set -euo pipefail

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.completed-phases"
TASKS_JSON="$HOME/.claude-monitor/tasks.json"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  # tasks.json があれば削除（タスク終了時）
  rm -f "$TASKS_JSON" 2>/dev/null
  exit 0
fi

# Read hook input
HOOK_INPUT=$(cat)

# パース結果を格納する変数
COMPLETED_PHASES=0
TOTAL_TASKS=0
TOTAL_DONE=0
CURRENT_PHASE=""
CURRENT_PHASE_NAME=""
PHASE_TOTAL=0
PHASE_DONE=0
ACTIVE_PHASE=""      # 未完了タスクがある最初のフェーズ
TASKS_JSON_ARRAY=""  # JSON用タスク配列

while IFS= read -r line; do
  # ## 見出しでフェーズ区切り
  if echo "$line" | grep -qE '^##\s+Phase'; then
    # 前のフェーズの完了判定
    if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
      COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
    fi
    CURRENT_PHASE="$line"
    CURRENT_PHASE_NAME=$(echo "$line" | sed 's/^##[[:space:]]*//')
    PHASE_TOTAL=0
    PHASE_DONE=0
    continue
  fi
  # タスク行の検出（- [ ] N-M: or - [x] N-M:）
  if echo "$line" | grep -qE '^\s*-\s*\[[ x]\]'; then
    TOTAL_TASKS=$((TOTAL_TASKS + 1))
    PHASE_TOTAL=$((PHASE_TOTAL + 1))

    # タスクID と名前を抽出
    TASK_ID=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*\[[ x]\][[:space:]]*([0-9]+-[0-9]+):.*/\1/')
    TASK_NAME=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*\[[ x]\][[:space:]]*[0-9]+-[0-9]+:[[:space:]]*(.*)/\1/')

    if echo "$line" | grep -qE '^\s*-\s*\[x\]'; then
      PHASE_DONE=$((PHASE_DONE + 1))
      TOTAL_DONE=$((TOTAL_DONE + 1))
      TASK_STATUS="completed"
    else
      TASK_STATUS="pending"
      # 最初の未完了タスクがあるフェーズを記録
      if [[ -z "$ACTIVE_PHASE" ]]; then
        ACTIVE_PHASE="$CURRENT_PHASE_NAME"
      fi
    fi

    # JSON配列に追加
    if [[ -n "$TASKS_JSON_ARRAY" ]]; then
      TASKS_JSON_ARRAY="${TASKS_JSON_ARRAY},"
    fi
    # エスケープ処理
    ESCAPED_NAME=$(echo "$TASK_NAME" | sed 's/"/\\"/g')
    TASKS_JSON_ARRAY="${TASKS_JSON_ARRAY}{\"id\":\"${TASK_ID}\",\"name\":\"${ESCAPED_NAME}\",\"phase\":\"${CURRENT_PHASE_NAME}\",\"status\":\"${TASK_STATUS}\"}"
  fi
done < "$TASKS_FILE"

# 最後のフェーズの判定
if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
  COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
fi

# 進捗率計算
if [[ "$TOTAL_TASKS" -gt 0 ]]; then
  PROGRESS=$(( (TOTAL_DONE * 100) / TOTAL_TASKS ))
else
  PROGRESS=0
fi

# tasks.json 生成
mkdir -p "$(dirname "$TASKS_JSON")"
cat > "$TASKS_JSON" << EOF
{"phase":"${ACTIVE_PHASE:-completed}","progress":${PROGRESS},"completed":${TOTAL_DONE},"total":${TOTAL_TASKS},"tasks":[${TASKS_JSON_ARRAY}]}
EOF

# --- レビュートリガー ---

# 前回の完了フェーズ数を取得
if [[ -f "$COUNTER_FILE" ]]; then
  PREV_PHASES=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
else
  mkdir -p "$(dirname "$COUNTER_FILE")"
  PREV_PHASES=0
fi

# 新しいフェーズ完了を検知 → code-reviewer 実行を指示
if [[ "$COMPLETED_PHASES" -gt "$PREV_PHASES" ]]; then
  NEW_PHASES=$((COMPLETED_PHASES - PREV_PHASES))
  echo ""
  echo "🔍 フェーズ ${NEW_PHASES} 件完了 - code-reviewer subagent で変更をレビューしてから次のフェーズに進んでください。止まらずに継続すること。"
  echo ""
fi

# 現在の状態を保存
echo "$COMPLETED_PHASES" > "$COUNTER_FILE"

exit 0
