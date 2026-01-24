#!/bin/bash
# Reset task counter and clean old task IDs on session start
# SessionStart で実行
# 新セッションでTaskCreate IDが1から始まるようにリセットする

set -euo pipefail

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.task-counter"

# Read hook input (required by hook protocol)
cat > /dev/null

# Reset counter
rm -f "$COUNTER_FILE"

# Remove old task ID comments from tasks.md (keep checkbox state)
if [[ -f "$TASKS_FILE" ]]; then
  sed -i '' 's/ <!-- task:[0-9][0-9]*\( status:active\)\{0,1\} -->//' "$TASKS_FILE"
fi

exit 0
