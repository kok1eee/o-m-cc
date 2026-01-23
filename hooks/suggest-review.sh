#!/bin/bash
# Auto-trigger code review after task completion
# PostToolUse (Write|Edit) で実行
# tasks.md のタスク完了を検知して code-reviewer 実行を指示

set -euo pipefail

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.completed-tasks"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# Read hook input
HOOK_INPUT=$(cat)

# 現在の完了タスク数をカウント
CURRENT_COMPLETED=$(grep -ciE '^\s*-\s*\[x\]|status.*completed|✅.*TASK|TASK-[0-9]+.*完了|TASK-[0-9]+.*done' "$TASKS_FILE" 2>/dev/null || echo "0")

# 前回の完了タスク数を取得
if [[ -f "$COUNTER_FILE" ]]; then
  PREV_COMPLETED=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
else
  mkdir -p "$(dirname "$COUNTER_FILE")"
  PREV_COMPLETED=0
fi

# 新しいタスク完了を検知 → code-reviewer 実行を指示
if [[ "$CURRENT_COMPLETED" -gt "$PREV_COMPLETED" ]]; then
  NEW_COMPLETIONS=$((CURRENT_COMPLETED - PREV_COMPLETED))
  echo ""
  echo "🔍 タスク ${NEW_COMPLETIONS} 件完了 - code-reviewer subagent で変更をレビューしてから次のタスクに進んでください。止まらずに継続すること。"
  echo ""
fi

# 現在の状態を保存
echo "$CURRENT_COMPLETED" > "$COUNTER_FILE"

exit 0
