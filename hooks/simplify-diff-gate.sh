#!/bin/bash
# PreToolUse(Bash): push 前に diff 行数をチェックし、閾値超 + code-review 未実行なら block
#
# exit 2 でブロックすると stderr が Claude にフィードバックされ同ターン継続する。
# メッセージに Skill(code-review) 呼び出し指示を含めることで Claude が自動で整理→再 push する。
#
# 閾値の調整: 環境変数 CODE_REVIEW_DIFF_THRESHOLD で上書き可能（旧 SIMPLIFY_DIFF_THRESHOLD も fallback で読む）
# 例: 1000 行まで許容したいなら export CODE_REVIEW_DIFF_THRESHOLD=1000
#
# 通過方法:
# 1. Skill(code-review) を実行する → skill-usage.csv に記録され gate を通過
# 2. CODE_REVIEW_DIFF_THRESHOLD を大きくして push（推奨しない）
#
# 履歴: built-in /simplify は v2.1.146 で /code-review にリネーム。skill-usage.csv の旧
# 「simplify」エントリも match させて後方互換維持。ファイル名はそのまま (内部参照のみ)。
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

# 閾値（新 env var 優先 / 旧名 fallback / default 500 行）
THRESHOLD="${CODE_REVIEW_DIFF_THRESHOLD:-${SIMPLIFY_DIFF_THRESHOLD:-500}}"

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

# 閾値超え。code-review (旧 simplify) 実行マーカーをチェック
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
LOG_FILE="${PLUGIN_DATA}/skill-usage.csv"

# 最終 code-review / simplify 実行時刻（skill 列が "code-review" / "simplify" / "*:同" の最新タイムスタンプ）
LAST_REVIEW_ISO=""
if [[ -f "$LOG_FILE" ]]; then
  LAST_REVIEW_ISO=$(awk -F, 'NR>1 && $2 ~ /(^|:)(code-review|simplify)$/ {ts=$1} END {print ts}' "$LOG_FILE" 2>/dev/null || true)
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

LAST_REVIEW_EPOCH=$(to_epoch "$LAST_REVIEW_ISO")

# 最終コミット時刻 < code-review 時刻 → コミット後に code-review したと判定 → pass
if [[ "$LAST_REVIEW_EPOCH" -gt "$LAST_COMMIT_EPOCH" && "$LAST_REVIEW_EPOCH" -gt 0 ]]; then
  exit 0
fi

# Block + CTA
{
  echo ""
  echo "🚧 [code-review-diff-gate] push をブロックしました（diff ${DIFF_LINES} 行 > 閾値 ${THRESHOLD} 行）"
  echo "   最終コミット以降に /code-review が実行されていません。"
  echo ""
  echo "   → 今すぐ Skill(code-review) を呼び出してコードを整理し、その後 push を再試行してください。"
  echo ""
  echo "   ※ 閾値を変更したい場合: settings.json の env で CODE_REVIEW_DIFF_THRESHOLD=<行数> を設定"
  echo ""
} >&2

exit 2
