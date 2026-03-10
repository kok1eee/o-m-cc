#!/bin/bash
# Session Baseline - セッション開始時の diff 行数を記録
# stop-guard がセッション前の既存差分を除外するために使用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
fi

# stdin を消費（SessionStart hook は入力を受け取る）
cat > /dev/null

BASELINE_FILE=".claude/sisyphus-baseline.json"

# 変更行数を取得（stop-guard と同じロジック）
get_diff_lines() {
  local stat_line
  if check_command jj; then
    stat_line=$(jj diff --stat 2>/dev/null | tail -1)
  elif check_command git; then
    stat_line=$(git diff --stat HEAD 2>/dev/null | tail -1)
  fi
  local ins del
  ins=$(echo "$stat_line" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  del=$(echo "$stat_line" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
  echo $(( ${ins:-0} + ${del:-0} ))
}

DIFF_LINES=$(get_diff_lines)
mkdir -p "$(dirname "$BASELINE_FILE")"
echo "{\"baseline_diff\": ${DIFF_LINES}}" > "$BASELINE_FILE"

# 新セッション開始 → 前セッションの state + proof をクリア
STATE_FILE=".claude/sisyphus-state.json"
PROOF_FILE=".claude/quality-gate-proof.json"
rm -f "$STATE_FILE" "$PROOF_FILE"

exit 0
