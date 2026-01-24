#!/bin/bash
# Auto-trigger code review after phase completion
# PostToolUse (Write|Edit) で実行
# tasks.md のフェーズ完了を検知して code-reviewer 実行を指示

set -euo pipefail

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.completed-phases"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# Read hook input (required by Claude Code hook protocol)
HOOK_INPUT=$(cat)

# フェーズ完了数をカウント
COMPLETED_PHASES=0
CURRENT_PHASE=""
PHASE_TOTAL=0
PHASE_DONE=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '^##\s+Phase'; then
    # 前のフェーズの完了判定
    if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
      COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
    fi
    CURRENT_PHASE="$line"
    PHASE_TOTAL=0
    PHASE_DONE=0
    continue
  fi
  if echo "$line" | grep -qE '^\s*-\s*\[[ x]\]'; then
    PHASE_TOTAL=$((PHASE_TOTAL + 1))
    if echo "$line" | grep -qE '^\s*-\s*\[x\]'; then
      PHASE_DONE=$((PHASE_DONE + 1))
    fi
  fi
done < "$TASKS_FILE"

# 最後のフェーズの判定
if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
  COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
fi

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
