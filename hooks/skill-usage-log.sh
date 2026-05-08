#!/bin/bash
# PreToolUse: Skill ツールの使用をログ（trigger=claude-proactive）
# 公式 docs: PreToolUse Skill hook は Claude が proactive に skill を呼ぶ場合のみ発火。
# user-slash 起動は skill-prompt-log.sh (UserPromptExpansion) が補完する。
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記
# header: timestamp,skill,trigger,session_id,effort
set -euo pipefail

HOOK_INPUT=$(cat)

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

SKILL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null || echo "")
if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

# session_id は v2.1.132+ で Bash subprocess 環境変数として渡される
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

# effort は v2.1.133+ で env var / hook input JSON から取得（high / medium / low / xhigh）
EFFORT="${CLAUDE_EFFORT:-}"
if [[ -z "$EFFORT" ]]; then
  EFFORT=$(echo "$HOOK_INPUT" | jq -r '.effort.level // empty' 2>/dev/null || echo "")
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"
CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"

# Header migration:
#   旧1: "timestamp,skill"                       → 5 列
#   旧2: "timestamp,skill,trigger"               → 5 列
#   旧3: "timestamp,skill,trigger,session_id"    → 5 列
NEW_HEADER="timestamp,skill,trigger,session_id,effort"
if [[ -f "$CSV" ]]; then
  HEAD=$(head -n1 "$CSV")
  case "$HEAD" in
    "timestamp,skill"|"timestamp,skill,trigger"|"timestamp,skill,trigger,session_id")
      sed -i.bak "1s/.*/$NEW_HEADER/" "$CSV" && rm -f "$CSV.bak"
      ;;
  esac
else
  echo "$NEW_HEADER" > "$CSV"
fi

printf '%s,%s,%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SKILL_NAME}" "claude-proactive" "${SESSION_ID}" "${EFFORT}" >> "$CSV"

exit 0
