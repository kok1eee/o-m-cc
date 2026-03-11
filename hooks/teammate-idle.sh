#!/bin/bash
# Teammate Idle Handler
# TeammateIdle イベントで実行
# teammate が idle になったとき、残タスクへの着手を促す
#
# エスカレーションプロトコル:
#   Stage 1（1回目）: TaskList 確認を促す
#   Stage 2（2回目）: teammate を停止して再割り当て
#   Stage 3（3回目〜）: teammate を停止（エスカレーション）

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
  log_debug() { :; }
fi

IDLE_COUNT_DIR=".claude/idle-counts"

# Read hook input from stdin
HOOK_INPUT=$(cat)

# teammate 名を取得
if $HAS_JQ; then
  TEAMMATE_NAME=$(echo "$HOOK_INPUT" | jq -r '.teammate_name // .agent_name // "unknown"' 2>/dev/null || echo "unknown")
else
  TEAMMATE_NAME="unknown"
fi

log_debug "TeammateIdle: $TEAMMATE_NAME が idle になりました"

# --- エスカレーションカウント管理 ---
mkdir -p "$IDLE_COUNT_DIR"
SAFE_NAME=$(echo "$TEAMMATE_NAME" | tr -c '[:alnum:]-_' '_')
COUNT_FILE="${IDLE_COUNT_DIR}/${SAFE_NAME}"

if [[ -f "$COUNT_FILE" ]]; then
  IDLE_COUNT=$(cat "$COUNT_FILE")
  IDLE_COUNT=$((IDLE_COUNT + 1))
else
  IDLE_COUNT=1
fi
echo "$IDLE_COUNT" > "$COUNT_FILE"

# --- Stage 別メッセージ ---
if [[ $IDLE_COUNT -le 1 ]]; then
  # Stage 1: exit 2 → stderr が teammate にフィードバックされる
  echo "TaskList を確認し、未着手・ブロック解除済みのタスクをクレームして作業を続行してください。" >&2
  exit 2

elif [[ $IDLE_COUNT -eq 2 ]]; then
  # Stage 2: exit 0 + JSON で teammate を停止
  echo '{"continue": false, "stopReason": "2回目の idle — 再割り当てを検討"}'
  exit 0

else
  # Stage 3: exit 0 + JSON で teammate を停止（エスカレーション）
  echo '{"continue": false, "stopReason": "エスカレーション（'"${IDLE_COUNT}"'回目の idle）— 部分完了 or ユーザー相談"}'
  exit 0
fi
