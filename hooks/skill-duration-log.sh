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

# スキル名と duration_ms を 1 回の jq invocation で取得（hot path 軽量化）
# 出力: "<skill>\t<duration_ms>"。skill が空ならスキップ
IFS=$'\t' read -r SKILL_NAME DURATION_MS < <(
  echo "$HOOK_INPUT" | jq -r '[.tool_input.skill // "", (.duration_ms // 0) | tostring] | @tsv' 2>/dev/null || echo $'\t0'
)
if [[ -z "$SKILL_NAME" ]]; then
  exit 0
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"

CSV="${CLAUDE_PLUGIN_DATA}/skill-duration.csv"
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,skill,duration_ms" > "$CSV"
fi

# 追記（CSV: timestamp,skill,duration_ms）
printf '%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$SKILL_NAME" "$DURATION_MS" >> "$CSV"

exit 0
