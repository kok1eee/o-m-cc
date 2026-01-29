#!/bin/bash
# o-m-cc: Focus Guard - Keep Claude focused on current tasks
# UserPromptSubmit hook
#
# When tasks are in progress, inject a system message reminding Claude to:
# - Accept related corrections/changes to current work
# - Defer unrelated requests until current tasks are complete
#
# Does NOT block - just provides guidance via systemMessage

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  log_debug() { :; }
  check_command() { command -v "$1" >/dev/null 2>&1; }
fi

TASKS_FILE="spec/plan/tasks.md"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# 未完了タスクをカウント
PENDING_COUNT=$(grep -cE '^\s*-\s*\[ \]' "$TASKS_FILE" 2>/dev/null || echo "0")
PENDING_COUNT=$((PENDING_COUNT + 0))  # 数値化

# 未完了タスクがない場合はスキップ
if [[ "$PENDING_COUNT" -eq 0 ]]; then
  exit 0
fi

# 現在のフェーズとタスクを取得
CURRENT_PHASE=""
CURRENT_TASK=""
while IFS= read -r line; do
  if echo "$line" | grep -qE '^##\s+Phase'; then
    CURRENT_PHASE=$(echo "$line" | sed 's/^##[[:space:]]*//')
  fi
  if echo "$line" | grep -qE '^\s*-\s*\[ \]'; then
    if [[ -z "$CURRENT_TASK" ]]; then
      CURRENT_TASK=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[ \][[:space:]]*//' | head -c 50)
    fi
  fi
done < "$TASKS_FILE"

# jq がない場合はプレーンテキストで出力
if ! check_command jq; then
  echo ""
  echo "📋 タスク進行中 (残り ${PENDING_COUNT} 件)"
  exit 0
fi

# systemMessage を注入
jq -n --arg pending "$PENDING_COUNT" --arg phase "$CURRENT_PHASE" --arg task "$CURRENT_TASK" '{
  "systemMessage": ("📋 タスク進行中 (残り " + $pending + " 件: " + $phase + ")\n\nSisyphus原則: タスク完了まで止まらない。完了時は code-reviewer でレビューしてから DONE。\n\n作業中の割り込み対応:\n- 現在の作業に関連する修正・方向転換 → 反映する\n- 全く別の作業の依頼 → 「現在のタスク完了後に対応します」と返答し、必要ならメモを残す")
}'

exit 0
