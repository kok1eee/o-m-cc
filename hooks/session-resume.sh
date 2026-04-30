#!/bin/bash
# SessionStart: .claude/journal.md の最新エントリと skill-usage ログを表示
#
# Intent/Outcomes は Claude Code built-in /recap (v2.1.108+) の LLM 要約に委譲。
# ここでは journal.md の Next Actions（ユーザーが /handoff で記録したもの）と
# skill 使用統計だけを軽量に表示する。
set -euo pipefail

# CTA ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

# Headless モード（claude -p / CLAUDE_NON_INTERACTIVE=1）ではスキップ
if [[ "${CLAUDE_NON_INTERACTIVE:-}" = "1" ]]; then
  cat > /dev/null
  exit 0
fi

cat > /dev/null

JOURNAL_FILE=".claude/journal.md"

# journal.md も skill-usage も何もなければ何も出さない
if [[ ! -f "$JOURNAL_FILE" ]] && [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

# 1. journal.md の最新 1 エントリを表示
LATEST_ENTRY=""
if [[ -f "$JOURNAL_FILE" ]]; then
  # 最新エントリ: 最初の "## " 行から次の "## " 行の直前まで
  LATEST_ENTRY=$(awk '
    /^## / { if (started) exit; started=1 }
    started { print }
  ' "$JOURNAL_FILE")
fi

if [[ -n "$LATEST_ENTRY" ]]; then
  echo ""
  echo "🎯 最新 Journal (.claude/journal.md)"
  echo "$LATEST_ENTRY" | while IFS= read -r line; do
    echo "  ${line}"
  done
fi

# 2. skill-usage CSV（累計回数 + 最後のスキル）
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  USAGE_CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"
  if [[ -f "$USAGE_CSV" ]]; then
    TOTAL_USES=$(($(wc -l < "$USAGE_CSV" 2>/dev/null | tr -d ' ') - 1))
    if [[ "$TOTAL_USES" -gt 0 ]]; then
      LAST_SKILL=$(tail -1 "$USAGE_CSV" | awk -F, '{print $2}')
      echo ""
      echo "📊 スキル使用: 累計 ${TOTAL_USES} 回（最後: ${LAST_SKILL}）"
    fi
  fi
fi

# 3. CTA（journal.md があるときのみ）
if [[ -f "$JOURNAL_FILE" ]]; then
  emit_cta "journal.md を Read して次のアクションを確認（詳細要約は /recap）"
fi
echo ""
exit 0
