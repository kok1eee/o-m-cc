#!/bin/bash
# Session Baseline - セッション開始時の diff 行数を記録
# stop-guard がセッション前の既存差分を除外するために使用

set -euo pipefail

# Headless モード（claude -p）ではスキップ
if [[ "${CLAUDE_HEADLESS:-}" = "1" ]]; then
  cat > /dev/null
  exit 0
fi

# CLAUDE_PLUGIN_DATA 確認（2.1.78+）
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  echo "📦 CLAUDE_PLUGIN_DATA=${CLAUDE_PLUGIN_DATA}"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# hook input から cwd を取得してプロジェクトディレクトリに移動
HOOK_INPUT=$(cat)
PROJECT_CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
if [[ -n "$PROJECT_CWD" && -d "$PROJECT_CWD" ]]; then
  cd "$PROJECT_CWD"
fi

BASELINE_FILE=".claude/sisyphus-baseline.json"
CARRYOVER_FILE="${CLAUDE_PLUGIN_DATA:-/dev/null}/unreviewed-lines.json"

# get_diff_lines は common.sh で定義（cwd スコープ済み）

DIFF_LINES=$(get_diff_lines "$PROJECT_CWD")
mkdir -p "$(dirname "$BASELINE_FILE")"
echo "{\"baseline_diff\": ${DIFF_LINES}}" > "$BASELINE_FILE"

# セッション横断の累積カウント: 前セッションの未検証行数を引き継ぐ
CARRYOVER=0
if [[ -f "$CARRYOVER_FILE" ]]; then
  CARRYOVER=$(jq -r '.lines // 0' "$CARRYOVER_FILE" 2>/dev/null || echo "0")
  if [[ $CARRYOVER -gt 0 ]]; then
    echo "📊 前セッションからの未検証行数: ${CARRYOVER} 行"
  fi
fi

# 新セッション開始 → 前セッションの state + proof をクリア（carryover は保持）
STATE_FILE=".claude/sisyphus-state.json"
PROOF_FILE=".claude/quality-gate-proof.json"
RUNNING_FILE=".claude/quality-gate-running"
rm -f "$STATE_FILE" "$PROOF_FILE" "$RUNNING_FILE"

exit 0
