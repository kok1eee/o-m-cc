#!/bin/bash
# UserPromptExpansion: slash command 起動を記録（trigger=user-slash）
# 公式 docs: PreToolUse Skill hook は user-slash 起動では発火しないため、本 hook で補完する。
# ${CLAUDE_PLUGIN_DATA}/skill-usage.csv に追記
# header: timestamp,skill,trigger,session_id,effort,token_cost
# token_cost は常に空（実値収集は /usage の Desktop 対応後、EDD FR-4）
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

# session_id は v2.1.132+ で Bash subprocess 環境変数として渡される
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [[ -z "$SESSION_ID" ]]; then
  SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // empty' 2>/dev/null || echo "")
fi

# effort は v2.1.133+ で env var / hook input JSON から取得
EFFORT="${CLAUDE_EFFORT:-}"
if [[ -z "$EFFORT" ]]; then
  EFFORT=$(echo "$HOOK_INPUT" | jq -r '.effort.level // empty' 2>/dev/null || echo "")
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"
CSV="${CLAUDE_PLUGIN_DATA}/skill-usage.csv"

# Header migration: 2/3/4/5 列いずれも 6 列に揃える（token_cost 追加、EDD FR-4）
NEW_HEADER="timestamp,skill,trigger,session_id,effort,token_cost"
if [[ -f "$CSV" ]]; then
  HEAD=$(head -n1 "$CSV")
  case "$HEAD" in
    "timestamp,skill"|"timestamp,skill,trigger"|"timestamp,skill,trigger,session_id"|"timestamp,skill,trigger,session_id,effort")
      sed -i.bak "1s/.*/$NEW_HEADER/" "$CSV" && rm -f "$CSV.bak"
      ;;
  esac
else
  echo "$NEW_HEADER" > "$CSV"
fi

# 6 フィールド目 token_cost は常に空（実値は /usage Desktop 対応後）
printf '%s,%s,%s,%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$CMD_NAME" "user-slash" "${SESSION_ID}" "${EFFORT}" "" >> "$CSV"
exit 0
