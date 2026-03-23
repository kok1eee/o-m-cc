#!/bin/bash
# PreToolUse: Skill ツールの使用をログ
# ${CLAUDE_PLUGIN_DATA}/skill-usage.log に追記
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

# ログディレクトリ作成
mkdir -p "${CLAUDE_PLUGIN_DATA}"

# 追記（タイムスタンプ + スキル名）
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ${SKILL_NAME}" >> "${CLAUDE_PLUGIN_DATA}/skill-usage.log"

exit 0
