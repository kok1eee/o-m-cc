#!/bin/bash
# SubagentStop: サブエージェント完了時の軽量品質チェック
# ブロックしない（常に exit 0）。stderr に警告を出すだけ。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Headless モードではスキップ
if is_headless; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)

if ! check_command jq; then
  exit 0
fi

# サブエージェントの情報取得
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

# メインエージェントはスキップ（Stop hook の管轄）
if [[ -z "$AGENT_TYPE" || "$AGENT_TYPE" == "main" ]]; then
  exit 0
fi

# --- 軽量チェック ---

# 1. エラーパターンの検出
if echo "$LAST_MSG" | grep -qiE 'Error:|FAILED|panic:|Traceback|CRITICAL' 2>/dev/null; then
  echo "⚠️ [o-m-cc] サブエージェント ${AGENT_TYPE} の出力にエラーパターンを検出" >&2
fi

# 2. 極端に短い出力の警告
MSG_LEN=${#LAST_MSG}
if [[ $MSG_LEN -lt 20 && $MSG_LEN -gt 0 ]]; then
  echo "⚠️ [o-m-cc] サブエージェント ${AGENT_TYPE} の出力が極端に短い（${MSG_LEN}文字）" >&2
fi

exit 0
