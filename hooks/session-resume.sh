#!/bin/bash
# SessionStart: HANDOVER.md があれば表示
set -euo pipefail
HOOK_INPUT=$(cat)

HANDOVER_FILE="HANDOVER.md"
if [[ ! -f "$HANDOVER_FILE" ]]; then
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 前セッションの引き継ぎ (HANDOVER.md)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
# ヘッダーのみ表示（詳細は Read で確認）
grep '^## ' "$HANDOVER_FILE" 2>/dev/null | while IFS= read -r line; do
  echo "  ${line}"
done
echo ""
echo "詳細は HANDOVER.md を Read してください。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
exit 0
