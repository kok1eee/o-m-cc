#!/bin/bash
# PreToolUse(Bash): push 前に diff 行数をチェックし、閾値超 + simplify 未実行なら block
#
# 強制 mode (exit 2): diff 行数が SIMPLIFY_DIFF_THRESHOLD (default 500) を超え、
# かつ最終コミット以降に simplify が実行されていない場合に push を block。
# /simplify でコード整理してから再 push する運用を強制する。
#
# 閾値の調整: 環境変数 SIMPLIFY_DIFF_THRESHOLD で上書き可能（settings.json の env section など）
# 例: 1000 行まで許容したいなら export SIMPLIFY_DIFF_THRESHOLD=1000
#
# 通過方法:
# 1. /simplify を実行する → skill-usage.csv に記録され gate を通過
# 2. SIMPLIFY_DIFF_THRESHOLD を一時的に大きくして push（推奨しない）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
fi

# Headless モードではスキップ（強制 block されると CI 等で詰まるため）
if is_headless 2>/dev/null; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)

TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# push 系のみ反応（jj git push / git push）
if ! echo "$COMMAND" | grep -qE '(jj[[:space:]]+git[[:space:]]+push|^[[:space:]]*git[[:space:]]+push|[[:space:]&;|]git[[:space:]]+push)'; then
  exit 0
fi

# 閾値（環境変数で上書き可能、デフォルト 500 行）
THRESHOLD="${SIMPLIFY_DIFF_THRESHOLD:-500}"

# diff 行数を計算（main@origin / origin/HEAD ベースの変更分）
DIFF_LINES=0
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  # jj diff --stat の最終行 "N files changed, X insertions(+), Y deletions(-)" から数値合算
  STAT=$(jj diff --from 'main@origin' --to '@-' --stat 2>/dev/null | tail -1 || true)
  INS=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | awk '{print $1}' || echo 0)
  DEL=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | awk '{print $1}' || echo 0)
  DIFF_LINES=$(( ${INS:-0} + ${DEL:-0} ))
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  STAT=$(git diff origin/HEAD --shortstat 2>/dev/null || true)
  INS=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | awk '{print $1}' || echo 0)
  DEL=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | awk '{print $1}' || echo 0)
  DIFF_LINES=$(( ${INS:-0} + ${DEL:-0} ))
fi

if [[ "$DIFF_LINES" -lt "$THRESHOLD" ]]; then
  exit 0
fi

# 閾値超え。simplify 実行マーカーをチェック
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
LOG_FILE="${PLUGIN_DATA}/skill-usage.csv"

# 最終 simplify 実行時刻（skill 列が "simplify" or "*:simplify" の最新タイムスタンプ）
LAST_SIMPLIFY_ISO=""
if [[ -f "$LOG_FILE" ]]; then
  LAST_SIMPLIFY_ISO=$(awk -F, 'NR>1 && $2 ~ /(^|:)simplify$/ {ts=$1} END {print ts}' "$LOG_FILE" 2>/dev/null || true)
fi

# 直近コミット時刻
LAST_COMMIT_EPOCH=0
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  LAST_COMMIT_EPOCH=$(jj log -r '@-' --no-graph -T 'committer.timestamp().format("%s")' 2>/dev/null | head -1 || echo "0")
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  LAST_COMMIT_EPOCH=$(git log -1 --format='%ct' 2>/dev/null || echo "0")
fi
LAST_COMMIT_EPOCH=${LAST_COMMIT_EPOCH:-0}

# ISO8601 → epoch 変換
to_epoch() {
  local ts="$1"
  [[ -z "$ts" ]] && { echo "0"; return; }
  case "$(uname -s)" in
    Darwin*) date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null || echo "0" ;;
    *)       date -d "$ts" "+%s" 2>/dev/null || echo "0" ;;
  esac
}

LAST_SIMPLIFY_EPOCH=$(to_epoch "$LAST_SIMPLIFY_ISO")

# 最終コミット時刻 < simplify 時刻 → コミット後に simplify したと判定 → pass
if [[ "$LAST_SIMPLIFY_EPOCH" -gt "$LAST_COMMIT_EPOCH" && "$LAST_SIMPLIFY_EPOCH" -gt 0 ]]; then
  exit 0
fi

# Block + CTA
{
  echo ""
  echo "🚧 [simplify-diff-gate] diff が ${DIFF_LINES} 行で閾値 ${THRESHOLD} を超えています"
  echo "   この変更量だと整理されていない可能性があります（重複コード / 不要コメント / hacky パターン）。"
  echo ""
  echo "   通過するには次のいずれか:"
  echo "   1. /simplify でコード整理 → 再 push"
  echo "   2. 一時的に閾値を上げる: SIMPLIFY_DIFF_THRESHOLD=<行数> claude ..."
  echo ""
  echo "   現在の閾値変更: settings.json の env で SIMPLIFY_DIFF_THRESHOLD を設定"
  echo ""
} >&2

exit 2
