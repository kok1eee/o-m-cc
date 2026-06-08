#!/bin/bash
# PreToolUse(Bash): push 前に diff を scan し、秘密/認証情報の混入を検出したら block。
#
# 背景: permission-denied hook がファイルログに拒否コマンド本文（トークン入り）を記録し、
# それが公開 repo にコミット・push されて Slack Bot Token が漏洩した事故の構造的予防（A086）。
# common.sh のファイルログ廃止が「事後対処」なら、本 gate は「push 直前の物理ブロック（予防）」。
# 出典: SonicGarden self-improving-loop 記事の publicity-review gate。
#
# 設計:
# - push 系コマンド（jj git push / git push）にのみ反応
# - push される diff の追加行を scan。会話ログ *.jsonl は除外（私的 transcript の誤検知回避）
# - 実トークン形式に厳格マッチ（prose の "xoxb-..." 等は拾わない）
# - 検出時は secret 値を出さず「種別」だけ報告して exit 2 で block（stderr が Claude に渡る）
#
# bypass: 誤検知（ドキュメントの例示等）の場合 PUBLICITY_GATE_OFF=1 を設定して再 push。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
fi

# Headless（CI 等）/ 明示 OFF はスキップ
if is_headless 2>/dev/null; then
  cat > /dev/null
  exit 0
fi
if [[ "${PUBLICITY_GATE_OFF:-0}" == "1" ]]; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# push 系のみ反応（jj git push / git push）
if ! echo "$COMMAND" | grep -qE '(jj[[:space:]]+git[[:space:]]+push|(^|[[:space:]&;|])git[[:space:]]+push)'; then
  exit 0
fi

# push される diff（main@origin..@- の committed 範囲、simplify-diff-gate と同じ起点）
DIFF=""
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  DIFF=$(jj diff --git --from 'main@origin' --to '@-' 2>/dev/null || true)
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  DIFF=$(git diff origin/HEAD 2>/dev/null || true)
fi
[[ -z "$DIFF" ]] && exit 0

# 追加行のみ抽出。会話ログ *.jsonl は private transcript なので除外（誤検知回避）。
# +++ ヘッダで現在ファイルを追跡し、jsonl 以外の '+' 行だけ出力。
ADDED=$(echo "$DIFF" | awk '
  /^\+\+\+ / { f=substr($0,5); sub(/^b\//,"",f); next }
  /^\+/      { if (f !~ /\.jsonl$/) print }
' || true)
[[ -z "$ADDED" ]] && exit 0

# 秘密パターン（実トークン形式に厳格マッチ。誤検知を避けるため高信頼の 4 種に限定）
declare -A PATTERNS=(
  ["Slack token (xox*)"]='xox[baprs]-[0-9A-Za-z]{8,}-[0-9A-Za-z-]{8,}'
  ["AWS access key (AKIA)"]='AKIA[0-9A-Z]{16}'
  ["GitHub token (ghp/gho/...)"]='gh[pousr]_[0-9A-Za-z]{30,}'
  ["Private key block"]='-----BEGIN [A-Z ]*PRIVATE KEY-----'
)

HITS=()
for name in "${!PATTERNS[@]}"; do
  if echo "$ADDED" | grep -qE -- "${PATTERNS[$name]}"; then
    HITS+=("$name")
  fi
done

if [[ ${#HITS[@]} -eq 0 ]]; then
  exit 0
fi

# Block（secret 値は一切出さず、検出した種別だけ報告）
{
  echo ""
  echo "🚨 [publicity-gate] push をブロックしました — diff の追加行に秘密/認証情報らしきパターンを検出"
  for h in "${HITS[@]}"; do
    echo "     - ${h}"
  done
  echo ""
  echo "   公開 repo への secret 混入を仕組みで防ぐゲートです（A086）。"
  echo "   → jj diff（または git diff）で該当箇所を確認し、秘密を除去してから push を再試行してください。"
  echo "   → 誤検知（ドキュメントの例示・テストフィクスチャ等）の場合は PUBLICITY_GATE_OFF=1 を設定して再 push。"
  echo ""
} >&2

exit 2
