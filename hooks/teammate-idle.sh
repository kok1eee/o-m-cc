#!/bin/bash
# Teammate Idle Handler
# TeammateIdle イベントで実行
# teammate が idle になったとき、残タスクがあれば再割り当てを示唆
# 全 teammate idle + 全タスク完了なら完了判定
#
# エスカレーションプロトコル:
#   Stage 1（1回目）: 再割り当てを提案
#   Stage 2（2回目）: Lead が引き取るか再割り当て
#   Stage 3（3回目〜）: 部分完了 or ユーザー相談を促す

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

TASKS_FILE="plan/tasks.md"
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

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# 未完了タスク数をカウント
TOTAL_TASKS=0
COMPLETED_TASKS=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '^\s*-\s*\[[ x]\]'; then
    TOTAL_TASKS=$((TOTAL_TASKS + 1))
    if echo "$line" | grep -qE '^\s*-\s*\[x\]'; then
      COMPLETED_TASKS=$((COMPLETED_TASKS + 1))
    fi
  fi
done < "$TASKS_FILE"

REMAINING=$((TOTAL_TASKS - COMPLETED_TASKS))

if [[ $TOTAL_TASKS -eq 0 ]]; then
  exit 0
fi

if [[ $REMAINING -gt 0 ]]; then
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
  echo ""
  
  if [[ $IDLE_COUNT -le 1 ]]; then
    # Stage 1: exit 2 で teammate に作業続行を指示
    echo "💤 Teammate Idle: $TEAMMATE_NAME"
        echo ""
    echo "  📋 残タスク: ${REMAINING}/${TOTAL_TASKS}"
    emit_cta "TaskList を確認し、未着手・ブロック解除済みのタスクを自分でクレームして続行"

    emit_cta_system "残タスク ${REMAINING}/${TOTAL_TASKS} 件あります。TaskList を確認し、未着手・ブロック解除済みのタスクを自分でクレームして作業を続行してください。"
    exit 2

  elif [[ $IDLE_COUNT -eq 2 ]]; then
    # Stage 2: teammate を停止し、Lead に通知
    echo "⚠️  Teammate Idle (2回目): $TEAMMATE_NAME → 停止"
    echo ""
    echo "  📋 残タスク: ${REMAINING}/${TOTAL_TASKS}"

    emit_cta_system "⚠️ ${TEAMMATE_NAME} が2回目の idle のため停止しました。残タスク ${REMAINING}/${TOTAL_TASKS} 件 — Lead が直接引き取るか、別の teammate に再割り当てしてください。"
    # 2.1.69+: teammate を明示的に停止
    echo '{"continue": false, "stopReason": "2回目の idle — Lead が引き取るか再割り当て"}'

  else
    # Stage 3: teammate を停止し、エスカレーション
    echo "🚨 Teammate Idle (${IDLE_COUNT}回目): $TEAMMATE_NAME → 停止"
    echo ""
    echo "  📋 残タスク: ${REMAINING}/${TOTAL_TASKS}"

    emit_cta_system "🚨 エスカレーション: ${TEAMMATE_NAME} が ${IDLE_COUNT} 回目の idle のため停止しました。残タスク ${REMAINING}/${TOTAL_TASKS} 件 — 部分完了とするか、ユーザーに相談してください。"
    # 2.1.69+: teammate を明示的に停止
    echo '{"continue": false, "stopReason": "エスカレーション — 部分完了 or ユーザー相談"}'
  fi
else
  # 全タスク完了 → 完了判定（カウントをリセット）
  rm -rf "$IDLE_COUNT_DIR" 2>/dev/null || true

  echo ""
    echo "✅ 全タスク完了 (${COMPLETED_TASKS}/${TOTAL_TASKS})"
    emit_cta "/quality-gate で品質チェック" "<promise>DONE</promise> を出力"

  emit_cta_system "✅ 全タスク完了。/quality-gate で品質チェックを実行し、<promise>DONE</promise> を出力してください。"
fi

exit 0
