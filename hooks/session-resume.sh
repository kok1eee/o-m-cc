#!/bin/bash
# SessionStart: CONTEXT.md があれば表示
set -euo pipefail
HOOK_INPUT=$(cat)

CONTEXT_FILE="CONTEXT.md"
if [[ ! -f "$CONTEXT_FILE" ]]; then
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 前セッションの文脈 (CONTEXT.md)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
# セクションヘッダーとダイジェストエントリを表示
grep -E '^## |^- \[' "$CONTEXT_FILE" 2>/dev/null | while IFS= read -r line; do
  echo "  ${line}"
done
echo ""
echo "詳細は CONTEXT.md を Read してください。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
exit 0
