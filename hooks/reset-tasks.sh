#!/bin/bash
# Reset task counter and clean old task IDs on session start
# SessionStart で実行
# 新セッションでTaskCreate IDが1から始まるようにリセットする

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  sed_inplace() { sed -i '' "$1" "$2" 2>/dev/null || sed -i "$1" "$2"; }
  log_debug() { :; }
fi

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.task-counter"

# Read hook input (required by hook protocol)
cat > /dev/null

# Reset counter
rm -f "$COUNTER_FILE"
log_debug "タスクカウンターをリセット"

# Remove old task ID comments from tasks.md (keep checkbox state)
if [[ -f "$TASKS_FILE" ]]; then
  sed_inplace 's/ <!-- task:[0-9][0-9]*\( status:active\)\{0,1\} -->//' "$TASKS_FILE"
  log_debug "tasks.md からタスクIDコメントを削除"
fi

exit 0
