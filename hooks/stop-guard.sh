#!/bin/bash
# Sisyphus Stop Guard with Code Review
# DONE検知時にcode-reviewerの結果を確認し、問題があればループ継続
# max_iterations で安全弁を提供

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

# CTA ライブラリ読み込み
if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

# jq がない場合はスキップ
if ! check_command jq; then
  log_error "jq がインストールされていないため stop-guard をスキップ"
  exit 0
fi

# Configuration
STATE_FILE=".claude/sisyphus-state.json"
MAX_ITERATIONS="${SISYPHUS_MAX_ITERATIONS:-50}"
MAX_SAME_REASON="${SISYPHUS_MAX_SAME_REASON:-3}"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")

# Initialize or update state file
init_state() {
  if [[ ! -f "$STATE_FILE" ]]; then
    mkdir -p "$(dirname "$STATE_FILE")"
    echo '{"iteration": 0, "started_at": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'", "last_reasons": []}' > "$STATE_FILE"
  fi
}

get_iteration() {
  jq -r '.iteration // 0' "$STATE_FILE" 2>/dev/null || echo "0"
}

increment_iteration_with_reason() {
  local reason="${1:-unknown}"
  local current
  current=$(get_iteration)
  local next=$((current + 1))
  local started_at
  started_at=$(jq -r '.started_at' "$STATE_FILE" 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)
  # 最新3件の理由を保持
  jq --arg reason "$reason" --arg next "$next" --arg started_at "$started_at" '
    .iteration = ($next | tonumber) |
    .started_at = $started_at |
    .last_reasons = ((.last_reasons // []) + [$reason] | .[-3:])
  ' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
  echo "$next"
}

# スロットリング: 同じ理由で MAX_SAME_REASON 回連続ブロックしたら強制停止
check_throttle() {
  local reason_count
  reason_count=$(jq -r '.last_reasons | if length >= '"$MAX_SAME_REASON"' then (group_by(.) | map(select(length >= '"$MAX_SAME_REASON"')) | length) else 0 end' "$STATE_FILE" 2>/dev/null || echo "0")
  if [[ "$reason_count" -gt 0 ]]; then
    local repeated_reason
    repeated_reason=$(jq -r '.last_reasons[-1]' "$STATE_FILE" 2>/dev/null || echo "unknown")
    echo "🔁 SISYPHUS GUARD: 同じ問題で ${MAX_SAME_REASON} 回ループ検出（理由: ${repeated_reason}）"
    echo "アプローチを変えるか、人間の判断が必要です。"
    cleanup_state
    exit 0
  fi
}

cleanup_state() {
  rm -f "$STATE_FILE"
}

# Check max iterations and throttle
init_state
check_throttle
CURRENT_ITERATION=$(get_iteration)

if [[ $CURRENT_ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 SISYPHUS GUARD: Max iterations ($MAX_ITERATIONS) に到達。安全弁が作動しました。"
  cleanup_state
  exit 0
fi

# Get last assistant message
# 2.1.47+: last_assistant_message が hook input に含まれる
LAST_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

# フォールバック: last_assistant_message がない場合はトランスクリプトから取得
if [[ -z "$LAST_OUTPUT" ]]; then
  if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
    exit 0
  fi
  if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null; then
    exit 0
  fi
  LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
  LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
    .message.content |
    map(select(.type == "text")) |
    map(.text) |
    join("\n")
  ' 2>/dev/null || echo "")
fi

# Check for <promise>DONE</promise>
if echo "$LAST_OUTPUT" | grep -q '<promise>DONE</promise>'; then

  # /simplify と /review の両方の実行証拠があるか？
  HAS_SIMPLIFY=$(echo "$LAST_OUTPUT" | grep -qiE '/simplify|simplify.*完了|simplify.*実行' && echo "1" || echo "0")
  HAS_REVIEW=$(echo "$LAST_OUTPUT" | grep -qiE 'code-reviewer|コードレビュー|レビュー.*完了|Critical.*なし' && echo "1" || echo "0")

  if [[ "$HAS_SIMPLIFY" == "1" && "$HAS_REVIEW" == "1" ]]; then
    # 証拠あり → 終了許可
    echo ""
    echo "✅ Sisyphus Guard: /simplify + /review 完了を確認 - 終了を許可"
    cleanup_state
    exit 0
  else
    # 証拠なし → ブロック
    increment_iteration_with_reason "no_quality_check"
    emit_cta_block "⚠️ Sisyphus Guard: /simplify → /review を実行してください" \
      "/simplify でコード品質を改善" "/review でレビュー" "<promise>DONE</promise> を出力"
    exit 0
  fi
fi

# No DONE detected - allow normal exit
exit 0
