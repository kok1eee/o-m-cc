#!/bin/bash
# CTA (Call To Action) ヘルパー
# hooks から Claude Code に「次のアクション」を構造的に伝える
#
# Usage:
#   source "${SCRIPT_DIR}/lib/cta.sh"
#
#   # テキスト CTA（人間にも読みやすい）
#   emit_cta "/quality-gate で品質チェック"
#
#   # systemMessage 付き CTA（Claude Code の systemMessage に注入）
#   emit_cta_system "次のタスクに進んでください"
#
#   # ブロック CTA（バナー + JSON。exit は呼び出し元で）
#   emit_cta_block "⚠️ Sisyphus Guard: /quality-gate を実行してください" \
#     "/quality-gate で品質チェック" "DONE を出力"

# =============================================================================
# テキスト CTA
# =============================================================================
# hook の stdout に構造化された「次のアクション」を出力
# Claude Code はテキストとして受け取り、次のステップを理解する
emit_cta() {
  if [[ $# -eq 0 ]]; then
    return
  fi

  echo ""
  echo "→ Next:"
  for action in "$@"; do
    echo "  - ${action}"
  done
}

# =============================================================================
# systemMessage CTA
# =============================================================================
# Claude Code の systemMessage に注入される JSON を出力
# task-completed, teammate-idle 等で使用
emit_cta_system() {
  local msg="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg msg "$msg" '{ "systemMessage": $msg }'
  else
    local escaped_msg
    escaped_msg=$(printf '%s' "$msg" | sed 's/"/\\"/g')
    printf '{"systemMessage":"%s"}\n' "$escaped_msg"
  fi
}

# =============================================================================
# ブロック CTA
# =============================================================================
# バナー表示 + テキスト CTA + ブロック JSON を一括出力
# stop-guard の decision/reason/systemMessage パターンを汎用化
# exit は呼び出し元で行う
emit_cta_block() {
  local system_msg="$1"
  shift
  local actions=("$@")

  # テキスト CTA
  emit_cta "${actions[@]}"

  # reason: アクションを → で連結（自然な読み順）
  local reason=""
  for action in "${actions[@]}"; do
    if [[ -n "$reason" ]]; then
      reason="${reason} → ${action}"
    else
      reason="${action}"
    fi
  done

  # ブロック JSON
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg reason "$reason" \
      --arg msg "$system_msg" \
      '{
        "decision": "block",
        "reason": $reason,
        "systemMessage": $msg
      }'
  else
    local escaped_reason escaped_msg
    escaped_reason=$(printf '%s' "$reason" | sed 's/"/\\"/g')
    escaped_msg=$(printf '%s' "$system_msg" | sed 's/"/\\"/g')
    printf '{"decision":"block","reason":"%s","systemMessage":"%s"}\n' "$escaped_reason" "$escaped_msg"
  fi
}
