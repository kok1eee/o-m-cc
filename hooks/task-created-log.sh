#!/bin/bash
# TaskCreated: タスク作成をログ
# ${CLAUDE_PLUGIN_DATA}/task-created.log に追記
set -euo pipefail

HOOK_INPUT=$(cat)

# CLAUDE_PLUGIN_DATA がなければスキップ
if [[ -z "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  exit 0
fi

# タスク情報を取得
TASK_TITLE=$(echo "$HOOK_INPUT" | jq -r '.tool_input.title // .tool_input.description // "untitled"' 2>/dev/null || echo "untitled")

# ログディレクトリ作成
mkdir -p "${CLAUDE_PLUGIN_DATA}"

# 追記（タイムスタンプ + タスクタイトル）
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ${TASK_TITLE}" >> "${CLAUDE_PLUGIN_DATA}/task-created.log"

exit 0
