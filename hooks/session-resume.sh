#!/bin/bash
# SessionStart: .claude/context.md + chronicle.md の概要を表示
set -euo pipefail

# CTA ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

# Headless モード（claude -p）ではスキップ
if [[ "${CLAUDE_HEADLESS:-}" = "1" ]]; then
  cat > /dev/null
  exit 0
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
NEXT_ACTIONS=""
if [[ -f "$CONTEXT_FILE" ]]; then
  echo "📋 最新の文脈 (.claude/context.md)"
  { grep -E '^\*\*(Intent|Outcomes)' "$CONTEXT_FILE" 2>/dev/null || true; } | head -2 | while IFS= read -r line; do
    echo "  ${line}"
  done

  # Next Actions を表示
  NEXT_ACTIONS=$(sed -n '/^\*\*Next:\*\*/,/^$/p' "$CONTEXT_FILE" 2>/dev/null | grep '^- ' || true)
  if [[ -n "$NEXT_ACTIONS" ]]; then
    echo ""
    echo "🎯 次のアクション"
    echo "$NEXT_ACTIONS" | while IFS= read -r line; do
      echo "  ${line}"
    done
  fi
fi

# chronicle.md の直近3件を表示
if [[ -f "$CHRONICLE_FILE" ]]; then
  ENTRIES=$(grep '^- \[' "$CHRONICLE_FILE" 2>/dev/null | head -3 || true)
  if [[ -n "$ENTRIES" ]]; then
    echo ""
    echo "📜 最近の経緯 (.claude/chronicle.md)"
    echo "$ENTRIES" | while IFS= read -r line; do
      echo "  ${line}"
    done
  fi
fi

# CLAUDE_PLUGIN_DATA 依存の表示（未検証行数 + スキル使用ログ）
# jq を使わず grep/sed で軽量化（JSON 構造が単純なため）
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  # スキル使用ログ
  USAGE_LOG="${CLAUDE_PLUGIN_DATA}/skill-usage.log"
  if [[ -f "$USAGE_LOG" ]]; then
    TOTAL_USES=$(wc -l < "$USAGE_LOG" 2>/dev/null | tr -d ' ')
    if [[ "$TOTAL_USES" -gt 0 ]]; then
      LAST_SKILL=$(tail -1 "$USAGE_LOG" | awk '{print $2}')
      echo ""
      echo "📊 スキル使用: 累計 ${TOTAL_USES} 回（最後: ${LAST_SKILL}）"
    fi
  fi
fi

if [[ -n "$NEXT_ACTIONS" ]]; then
  emit_cta ".claude/context.md を Read して次のアクションを確認"
else
  emit_cta ".claude/context.md を Read して文脈を復元"
fi
echo ""
exit 0
