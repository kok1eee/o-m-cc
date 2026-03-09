#!/bin/bash
# Sisyphus Stop Guard (simplified)
# DONE + Quality Gate proof の2段チェック。max_iterations で安全弁。

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
QUALITY_GATE_PROOF='<proof>QUALITY_GATE_PASSED</proof>'

HOOK_INPUT=$(cat)

# サブエージェントはスキップ
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_TYPE" && "$AGENT_TYPE" != "main" ]]; then
  exit 0
fi

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

increment() { echo "{\"iteration\": $((ITERATION + 1))}" > "$STATE_FILE"; }

LAST_OUTPUT=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

# DONE あり → proof チェック
if echo "$LAST_OUTPUT" | grep -q '<promise>DONE</promise>'; then
  if echo "$LAST_OUTPUT" | grep -qF "$QUALITY_GATE_PROOF"; then
    echo "✅ Sisyphus Guard: Quality Gate 通過を確認 - 終了を許可"
    rm -f "$STATE_FILE"
    exit 0
  else
    increment
    emit_cta_block "⚠️ Sisyphus Guard: /quality-gate を実行してください" \
      "/quality-gate で品質チェック" "<promise>DONE</promise> を出力"
    exit 2
  fi
fi

# DONE なし + 既にループ中 → 再ブロック
STOP_HOOK_ACTIVE=$(echo "$HOOK_INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo "false")
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
  increment
  emit_cta_block "⚠️ Sisyphus Guard: タスクが未完了です" \
    "タスクを完了させる" "<promise>DONE</promise> を出力して終了"
  exit 2
fi

# 初回 Stop → 素通り
exit 0
