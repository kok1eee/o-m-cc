#!/bin/bash
# UserPromptExpansion: slash command 起動を記録（trigger=user-slash）
# 公式 docs: PreToolUse Skill hook は user-slash 起動では発火しないため、本 hook で補完する。
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記（header: timestamp,skill,trigger）
set -euo pipefail

HOOK_INPUT=$(cat)

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

# expansion_type=="slash_command" 以外（@file 展開等）はスキップ
EXP_TYPE=$(echo "$HOOK_INPUT" | jq -r '.expansion_type // empty' 2>/dev/null || echo "")
if [[ "$EXP_TYPE" != "slash_command" ]]; then
  exit 0
fi

CMD_NAME=$(echo "$HOOK_INPUT" | jq -r '.command_name // empty' 2>/dev/null || echo "")
if [[ -z "$CMD_NAME" ]]; then
  exit 0
fi

# o-m-cc skill のみ記録（built-in /clear /help 等は除外）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(dirname "$SCRIPT_DIR")/skills"
SKILL_BASENAME="${CMD_NAME#o-m-cc:}"
if [[ ! -d "$SKILLS_DIR/$SKILL_BASENAME" ]]; then
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

printf '%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CMD_NAME" "user-slash" >> "$CSV"
exit 0
