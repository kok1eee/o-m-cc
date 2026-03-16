#!/bin/bash
# Session Baseline - セッション開始時の diff 行数を記録
# stop-guard がセッション前の既存差分を除外するために使用

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# stdin を消費（SessionStart hook は入力を受け取る）
cat > /dev/null

BASELINE_FILE=".claude/sisyphus-baseline.json"

# 変更行数を取得（stop-guard と同じロジック、plan/ 除外）
get_diff_lines() {
  local stat_line=""
  if check_command jj && jj root >/dev/null 2>&1; then
    stat_line=$(jj diff --stat -- 'all() & ~glob:"plan/**"' 2>/dev/null | tail -1) || true
  elif check_command git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    stat_line=$(git diff --stat HEAD -- . ':!plan/' 2>/dev/null | tail -1) || true
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
RUNNING_FILE=".claude/quality-gate-running"
rm -f "$STATE_FILE" "$PROOF_FILE" "$RUNNING_FILE"

exit 0
