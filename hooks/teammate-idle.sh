#!/bin/bash
# Teammate Idle Handler
# TeammateIdle イベントで実行
# teammate が idle になったとき、残タスクがあれば再割り当てを示唆
# 全 teammate idle + 全タスク完了なら完了判定

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

TASKS_FILE="spec/plan/tasks.md"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# teammate 名を取得
TEAMMATE_NAME=$(echo "$HOOK_INPUT" | jq -r '.teammate_name // .agent_name // "unknown"' 2>/dev/null || echo "unknown")

log_debug "TeammateIdle: $TEAMMATE_NAME が idle になりました"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# 未完了タスク数をカウント
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

if [[ $REMAINING -gt 0 ]]; then
  # 残タスクあり → 再割り当てを示唆
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💤 Teammate Idle: $TEAMMATE_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  📋 残タスク: ${REMAINING}/${TOTAL_TASKS}"
  echo "  → 未着手タスクがあります。この teammate に割り当てを検討してください。"
  echo ""

  jq -n --arg name "$TEAMMATE_NAME" --arg remaining "$REMAINING" --arg total "$TOTAL_TASKS" '{
    "systemMessage": ("💤 " + $name + " が idle です。残タスク " + $remaining + "/" + $total + " 件 — 未着手タスクの割り当てを検討してください。")
  }'
else
  # 全タスク完了 → 完了判定
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "✅ 全タスク完了 (${COMPLETED_TASKS}/${TOTAL_TASKS})"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  → code-reviewer teammate で最終レビューを実行し、"
  echo "    問題がなければ <promise>DONE</promise> を出力してください。"
  echo ""

  jq -n '{
    "systemMessage": "✅ 全タスク完了。code-reviewer teammate で最終レビューを実行し、<promise>DONE</promise> を出力してください。"
  }'
fi

exit 0
