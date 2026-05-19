#!/bin/bash
# SubagentStop hook: agent dispatch の elapsed duration を記録する。
# Claude Code v2.1.144+ で subagent completion 通知に elapsed duration が
# 追加された。hook input にも duration_ms 系のフィールドが含まれていれば
# 拾って ${CLAUDE_PLUGIN_DATA}/agent-duration.csv に追記する。
# 対応フィールド: .duration_ms / .duration / .elapsed_ms / .elapsed_duration_ms
# どれも無い場合は duration_ms=0 で記録（行は残し、find_agent_duration_stats で skip）
set -euo pipefail

HOOK_INPUT=$(cat)

if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

IFS=$'\t' read -r AGENT_TYPE DURATION_MS < <(
  echo "$HOOK_INPUT" | jq -r '
    [
      (.agent_type // ""),
      ((.duration_ms // .duration // .elapsed_ms // .elapsed_duration_ms // 0) | tostring)
    ] | @tsv
  ' 2>/dev/null || echo $'\t0'
)

if [[ -z "$AGENT_TYPE" || "$AGENT_TYPE" == "main" ]]; then
  exit 0
fi

mkdir -p "${CLAUDE_PLUGIN_DATA}"

CSV="${CLAUDE_PLUGIN_DATA}/agent-duration.csv"
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,agent_type,duration_ms" > "$CSV"
fi

printf '%s,%s,%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$AGENT_TYPE" "$DURATION_MS" >> "$CSV"

exit 0
