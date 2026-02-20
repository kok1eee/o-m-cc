#!/bin/bash
# Task Completed Handler
# TaskCompleted イベントで実行
# タスク完了時に tasks.md を同期し、依存タスクのアンブロックを通知
# 全タスク完了時に最終レビューを起動

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

TASKS_FILE="plan/tasks.md"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# 完了したタスク情報を取得
TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.task_id // .taskId // "unknown"' 2>/dev/null || echo "unknown")
TASK_SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.task_subject // .subject // ""' 2>/dev/null || echo "")

log_debug "TaskCompleted: タスク $TASK_ID ($TASK_SUBJECT) が完了"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# 進捗をカウント
TOTAL_TASKS=0
COMPLETED_TASKS=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s*-\s*\[[ x]\]'; then
    TOTAL_TASKS=$((TOTAL_TASKS + 1))
    if echo "$line" | grep -qE '^\s*-\s*\[x\]'; then
      COMPLETED_TASKS=$((COMPLETED_TASKS + 1))
    fi
  fi
done < "$TASKS_FILE"

REMAINING=$((TOTAL_TASKS - COMPLETED_TASKS))

if [[ $TOTAL_TASKS -eq 0 ]]; then
  exit 0
fi

# 進捗表示
PROGRESS_PCT=0
if [[ $TOTAL_TASKS -gt 0 ]]; then
  PROGRESS_PCT=$((COMPLETED_TASKS * 100 / TOTAL_TASKS))
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Task Completed: $TASK_ID"
if [[ -n "$TASK_SUBJECT" ]]; then
  echo "   $TASK_SUBJECT"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📊 進捗: ${COMPLETED_TASKS}/${TOTAL_TASKS} (${PROGRESS_PCT}%)"

if [[ $REMAINING -gt 0 ]]; then
  echo "  📋 残タスク: ${REMAINING} 件"
  echo "  → 次の未着手タスクをクレームして作業を続行してください。"
  echo ""

  jq -n --arg id "$TASK_ID" --arg completed "$COMPLETED_TASKS" --arg total "$TOTAL_TASKS" --arg remaining "$REMAINING" '{
    "systemMessage": ("✅ タスク " + $id + " 完了 (" + $completed + "/" + $total + ")。残 " + $remaining + " 件 — TaskList を確認し、次の未着手・ブロック解除済みタスクをクレームして続行してください。")
  }'
  exit 2
else
  echo ""
  echo "  🎉 全タスク完了！"
  echo "  → code-reviewer teammate で最終レビューを実行してください。"
  echo ""

  jq -n --arg completed "$COMPLETED_TASKS" '{
    "systemMessage": ("🎉 全 " + $completed + " タスク完了！code-reviewer teammate で最終レビューを実行し、<promise>DONE</promise> を出力してください。")
  }'
fi

exit 0
