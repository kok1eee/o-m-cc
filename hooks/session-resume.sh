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
  # 未検証行数
  CARRYOVER_FILE="${CLAUDE_PLUGIN_DATA}/unreviewed-lines.json"
  if [[ -f "$CARRYOVER_FILE" ]]; then
    UNREVIEWED=$(grep -oE '"lines":[[:space:]]*[0-9]+' "$CARRYOVER_FILE" 2>/dev/null | grep -oE '[0-9]+' || echo "0")
    if [[ "$UNREVIEWED" -gt 0 ]]; then
      echo ""
      echo "⚠️ 未検証コード: ${UNREVIEWED} 行（前セッションからの累積）"
      [[ "$UNREVIEWED" -ge 500 ]] && echo "   → /quality-gate の実行を推奨"
    fi
  fi
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

emit_cta ".claude/context.md を Read して文脈を復元"
echo ""
exit 0
