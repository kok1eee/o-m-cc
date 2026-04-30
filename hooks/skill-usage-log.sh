#!/bin/bash
# PreToolUse: Skill ツールの使用をログ
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記（header: timestamp,skill）
set -euo pipefail

HOOK_INPUT=$(cat)

# CLAUDE_PLUGIN_DATA がなければスキップ
if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

# スキル名を取得
SKILL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_input.skill // empty' 2>/dev/null || echo "")
if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"

CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"
# header を初回だけ書く
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,skill" > "$CSV"
fi

# 追記（CSV: timestamp,skill）
printf '%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${SKILL_NAME}" >> "$CSV"

exit 0
