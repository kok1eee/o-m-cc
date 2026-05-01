#!/bin/bash
# PreToolUse: Skill ツールの使用をログ（trigger=claude-proactive）
# 公式 docs: PreToolUse Skill hook は Claude が proactive に skill を呼ぶ場合のみ発火。
# user-slash 起動は skill-prompt-log.sh (UserPromptExpansion) が補完する。
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記（header: timestamp,skill,trigger）
set -euo pipefail

HOOK_INPUT=$(cat)

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

SKILL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null || echo "")
if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"
CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"

# Header migration: 旧 "timestamp,skill" → "timestamp,skill,trigger"
if [[ -f "$CSV" ]]; then
  HEAD=$(head -n1 "$CSV")
  if [[ "$HEAD" == "timestamp,skill" ]]; then
    sed -i.bak '1s/.*/timestamp,skill,trigger/' "$CSV" && rm -f "$CSV.bak"
  fi
else
  echo "timestamp,skill,trigger" > "$CSV"
fi

printf '%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SKILL_NAME}" "claude-proactive" >> "$CSV"

exit 0
