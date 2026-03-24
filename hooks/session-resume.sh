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

# 未検証行数の表示（セッション横断の累積）
CARRYOVER_FILE="${CLAUDE_PLUGIN_DATA:-}/unreviewed-lines.json"
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "$CARRYOVER_FILE" ]]; then
  UNREVIEWED=$(jq -r '.lines // 0' "$CARRYOVER_FILE" 2>/dev/null || echo "0")
  if [[ "$UNREVIEWED" -gt 0 ]]; then
    echo ""
    echo "⚠️ 未検証コード: ${UNREVIEWED} 行（前セッションからの累積）"
    if [[ "$UNREVIEWED" -ge 500 ]]; then
      echo "   → /quality-gate の実行を推奨"
    fi
  fi
fi

# スキル使用ログのサマリー
USAGE_LOG="${CLAUDE_PLUGIN_DATA:-}/skill-usage.log"
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "$USAGE_LOG" ]]; then
  TOTAL_USES=$(wc -l < "$USAGE_LOG" 2>/dev/null | tr -d ' ')
  LAST_SKILL=$(tail -1 "$USAGE_LOG" 2>/dev/null | awk '{print $2}' || echo "")
  if [[ "$TOTAL_USES" -gt 0 ]]; then
    echo ""
    echo "📊 スキル使用: 累計 ${TOTAL_USES} 回（最後: ${LAST_SKILL}）"
  fi
fi

echo ""
echo "🧭 ワークフロー"
echo "  ピンポイント修正 → そのまま実行"
echo "  複数ファイル変更 → /plan"
echo "  新機能・設計判断 → /sisyphus"
echo "  最適化・リファクタリング → /experiment"
echo "  完了前 → /verification で証拠確認"

emit_cta ".claude/context.md を Read して文脈を復元"
echo ""
exit 0
