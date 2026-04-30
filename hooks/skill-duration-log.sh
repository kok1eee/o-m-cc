#!/bin/bash
# PostToolUse: Skill ツール完了時に実行時間を記録
# Claude Code 2.1.119+ が PostToolUse hook input に duration_ms を含める
# ${CLAUDE_PLUGIN_DATA}/skill-duration.csv に追記（header: timestamp,skill,duration_ms）
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

# duration_ms を取得（2.1.119 未満の環境では存在しない → 0 扱い）
DURATION_MS=$(echo "$HOOK_INPUT" | jq -r '.duration_ms // 0' 2>/dev/null || echo "0")

mkdir -p "${CLAUDE_PLUGIN_DATA}"

CSV="${CLAUDE_PLUGIN_DATA}/skill-duration.csv"
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,skill,duration_ms" > "$CSV"
fi

# 追記（CSV: timestamp,skill,duration_ms）
printf '%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SKILL_NAME" "$DURATION_MS" >> "$CSV"

exit 0
