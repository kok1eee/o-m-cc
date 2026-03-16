#!/bin/bash
# SessionStart: .claude/context.md + chronicle.md の概要を表示
set -euo pipefail

# CTA ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

cat > /dev/null

CONTEXT_FILE=".claude/context.md"
CHRONICLE_FILE=".claude/chronicle.md"

# context.md も chronicle.md もなければスキップ
if [[ ! -f "$CONTEXT_FILE" ]] && [[ ! -f "$CHRONICLE_FILE" ]]; then
  exit 0
fi

echo ""

# 最新スナップショットを表示
if [[ -f "$CONTEXT_FILE" ]]; then
  echo "📋 最新の文脈 (.claude/context.md)"
  { grep -E '^\*\*(Intent|Outcomes)' "$CONTEXT_FILE" 2>/dev/null || true; } | head -2 | while IFS= read -r line; do
    echo "  ${line}"
  done
fi

# chronicle.md の直近5件を表示
if [[ -f "$CHRONICLE_FILE" ]]; then
  ENTRIES=$(grep '^- \[' "$CHRONICLE_FILE" 2>/dev/null | head -5 || true)
  if [[ -n "$ENTRIES" ]]; then
    echo ""
    echo "📜 最近の経緯 (.claude/chronicle.md)"
    echo "$ENTRIES" | while IFS= read -r line; do
      echo "  ${line}"
    done
  fi
fi

emit_cta ".claude/context.md を Read して文脈を復元"
echo ""
exit 0
