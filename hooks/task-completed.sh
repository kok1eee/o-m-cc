#!/bin/bash
# Task Completed Handler
# TaskCompleted イベントで実行
# タスク完了時に次タスクへの着手を促す

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
  log_debug() { :; }
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# 完了したタスク情報を取得
if check_command jq; then
  TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.task_id // .taskId // "unknown"' 2>/dev/null || echo "unknown")
  TASK_SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.task_subject // .subject // ""' 2>/dev/null || echo "")
else
  TASK_ID="unknown"
  TASK_SUBJECT=""
fi

log_debug "TaskCompleted: タスク $TASK_ID ($TASK_SUBJECT) が完了"

# exit 2 → stderr が model にフィードバックされる
echo "タスク ${TASK_ID} 完了。TaskList を確認し、次の未着手・ブロック解除済みタスクに着手してください。" >&2
exit 2
