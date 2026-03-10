#!/bin/bash
# Sisyphus Stop Guard (diff-based)
# ファイル変更量ベースで quality-gate を強制。DONE マーカー不要。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
fi

if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

if ! check_command jq; then
  exit 0
fi

# Configuration
STATE_FILE=".claude/sisyphus-state.json"
MAX_ITERATIONS="${SISYPHUS_MAX_ITERATIONS:-50}"
MIN_DIFF="${SISYPHUS_MIN_DIFF:-500}"
QUALITY_GATE_PROOF='<proof>QUALITY_GATE_PASSED</proof>'

HOOK_INPUT=$(cat)

# サブエージェントはスキップ
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_TYPE" && "$AGENT_TYPE" != "main" ]]; then
  exit 0
fi

# 変更行数を取得（jj → git fallback）
get_diff_lines() {
  local stat_line
  if check_command jj; then
    stat_line=$(jj diff --stat 2>/dev/null | tail -1)
  elif check_command git; then
    stat_line=$(git diff --stat HEAD 2>/dev/null | tail -1)
  fi
  # "3 files changed, 42 insertions(+), 10 deletions(-)" → 42 + 10 = 52
  local ins del
  ins=$(echo "$stat_line" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  del=$(echo "$stat_line" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
  echo $(( ${ins:-0} + ${del:-0} ))
}

DIFF_LINES=$(get_diff_lines)

# ベースライン計算: max(セッション開始時, 前回 quality-gate 通過時)
BASELINE_FILE=".claude/sisyphus-baseline.json"
BASELINE=0
if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE=$(jq -r '.baseline_diff // 0' "$BASELINE_FILE" 2>/dev/null || echo "0")
fi
PASSED_AT=0
if [[ -f "$STATE_FILE" ]]; then
  PASSED_AT=$(jq -r '.passed_at_diff // 0' "$STATE_FILE" 2>/dev/null || echo "0")
fi

# コミット検出: 総 diff が passed_at を下回った → コミットが行われたのでリセット
if [[ $PASSED_AT -gt 0 && $DIFF_LINES -lt $PASSED_AT ]]; then
  PASSED_AT=0
  rm -f "$STATE_FILE"
fi

EFFECTIVE_BASELINE=$(( BASELINE > PASSED_AT ? BASELINE : PASSED_AT ))
EFFECTIVE_DIFF=$(( DIFF_LINES - EFFECTIVE_BASELINE ))
if [[ $EFFECTIVE_DIFF -lt 0 ]]; then
  EFFECTIVE_DIFF=0
fi

# 実効変更が閾値未満 → 素通り（雑談・軽微な変更・既存差分のみ）
if [[ $EFFECTIVE_DIFF -lt $MIN_DIFF ]]; then
  exit 0
fi

# --- 以下、変更が閾値以上の場合のみ実行 ---

# Iteration counter
if [[ -f "$STATE_FILE" ]]; then
  ITERATION=$(jq -r '.iteration // 0' "$STATE_FILE" 2>/dev/null || echo "0")
else
  mkdir -p "$(dirname "$STATE_FILE")"
  ITERATION=0
fi

if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 SISYPHUS GUARD: Max iterations ($MAX_ITERATIONS) に到達。"
  rm -f "$STATE_FILE"
  exit 0
fi

increment() {
  jq -n --argjson iter "$((ITERATION + 1))" --argjson pat "$PASSED_AT" \
    '{iteration: $iter, passed_at_diff: $pat}' > "$STATE_FILE"
}

LAST_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

# proof マーカーあり → 通過（現在の diff をベースラインとして記録）
if echo "$LAST_OUTPUT" | grep -qF "$QUALITY_GATE_PROOF"; then
  echo "✅ Sisyphus Guard: Quality Gate 通過を確認（変更 ${EFFECTIVE_DIFF} 行）"
  jq -n --argjson pat "$DIFF_LINES" '{iteration: 0, passed_at_diff: $pat}' > "$STATE_FILE"
  exit 0
fi

# proof なし → ブロック（exit 0 + JSON decision で制御）
increment
if check_command jq; then
  jq -n \
    --arg reason "セッション中に ${EFFECTIVE_DIFF} 行の変更があります。今すぐ /quality-gate を実行してください。他のことはしないでください。" \
    '{ "decision": "block", "reason": $reason }'
else
  printf '{"decision":"block","reason":"セッション中に %d 行の変更があります。今すぐ /quality-gate を実行してください。"}\n' "$EFFECTIVE_DIFF"
fi
exit 0
