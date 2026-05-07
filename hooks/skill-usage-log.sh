#!/bin/bash
# PreToolUse: Skill ツールの使用をログ（trigger=claude-proactive）
# 公式 docs: PreToolUse Skill hook は Claude が proactive に skill を呼ぶ場合のみ発火。
# user-slash 起動は skill-prompt-log.sh (UserPromptExpansion) が補完する。
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記（header: timestamp,skill,trigger,session_id）
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
# 旧バージョンでは hook input JSON から取得（v2.1.105+ で session_id key 提供）
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"
CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"

# Header migration:
#   旧1: "timestamp,skill"          → "timestamp,skill,trigger,session_id"
#   旧2: "timestamp,skill,trigger"  → "timestamp,skill,trigger,session_id"
if [[ -f "$CSV" ]]; then
  HEAD=$(head -n1 "$CSV")
  if [[ "$HEAD" == "timestamp,skill" || "$HEAD" == "timestamp,skill,trigger" ]]; then
    sed -i.bak '1s/.*/timestamp,skill,trigger,session_id/' "$CSV" && rm -f "$CSV.bak"
  fi
else
  echo "timestamp,skill,trigger,session_id" > "$CSV"
fi

printf '%s,%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SKILL_NAME}" "claude-proactive" "${SESSION_ID}" >> "$CSV"

exit 0
