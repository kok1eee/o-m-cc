#!/bin/bash
# PermissionDenied hook: auto mode で拒否されたツール使用をログし、
# モデルに代替アプローチを促す
#
# 入力: hook JSON（tool_name, tool_input 等）
# 出力: モデルへのフィードバックメッセージ
# リトライ: しない（auto mode の判断を尊重）

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Headless モードではスキップ
if is_headless; then
  cat > /dev/null
  exit 0
fi

if ! check_command jq; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)

# ツール情報を抽出
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // .tool // "unknown"' 2>/dev/null || echo "unknown")
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // .input.command // empty' 2>/dev/null || echo "")

# ログ記録
LOG_MSG="PermissionDenied: tool=${TOOL_NAME}"
if [[ -n "$COMMAND" ]]; then
  LOG_MSG="${LOG_MSG}, command=$(echo "$COMMAND" | cut -c1-100)"
fi
log_warn "$LOG_MSG"

# PLUGIN_DATA に JSONL で記録（セッション横断の追跡用）
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  mkdir -p "${CLAUDE_PLUGIN_DATA}"
  DENIAL_LOG="${CLAUDE_PLUGIN_DATA}/permission-denials.jsonl"
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  # command は先頭 200 文字に切り詰めて記録（拒否されたコマンドに秘密情報が
  # 含まれていた場合の平文残留を抑える。ログ衛生 / OWASP-NIST 監査 P1）
  echo "$HOOK_INPUT" | jq -c --arg ts "$TIMESTAMP" \
    '{timestamp: $ts, tool: (.tool_name // .tool // "unknown"), command: ((.tool_input.command // .input.command // null) | if type == "string" then .[:200] else . end)}' \
    >> "$DENIAL_LOG" 2>/dev/null || true

  # ログローテーション（100行超過時）
  if [[ -f "$DENIAL_LOG" ]]; then
    LINE_COUNT=$(wc -l < "$DENIAL_LOG" 2>/dev/null || echo "0")
    LINE_COUNT=$((LINE_COUNT + 0))
    if [[ $LINE_COUNT -gt 100 ]]; then
      tail -50 "$DENIAL_LOG" > "${DENIAL_LOG}.tmp" && mv "${DENIAL_LOG}.tmp" "$DENIAL_LOG"
    fi
  fi
fi

# モデルへのフィードバック（stdout → モデルのコンテキスト）
if [[ -n "$COMMAND" ]]; then
  echo "⚠️ auto mode が「${TOOL_NAME}: $(echo "$COMMAND" | cut -c1-80)」を拒否しました。安全な代替手段を試してください。"
else
  echo "⚠️ auto mode が「${TOOL_NAME}」を拒否しました。安全な代替手段を試してください。"
fi

exit 0
