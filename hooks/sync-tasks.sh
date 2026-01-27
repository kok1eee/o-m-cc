#!/bin/bash
# Sync TaskCreate/TaskUpdate to spec/plan/tasks.md
# PostToolUse (TaskCreate|TaskUpdate) で実行
# cc-sidebar がこのファイルを監視して進捗表示する

set -euo pipefail

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.task-counter"

# Read hook input
HOOK_INPUT=$(cat)

# Extract tool name and input
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)

if [[ -z "$TOOL_NAME" ]]; then
  exit 0
fi

case "$TOOL_NAME" in
  TaskCreate)
    SUBJECT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.subject // empty' 2>/dev/null || true)
    if [[ -z "$SUBJECT" ]]; then
      exit 0
    fi

    # Increment counter to get task ID
    mkdir -p "$(dirname "$TASKS_FILE")"
    mkdir -p "$(dirname "$COUNTER_FILE")"
    if [[ -f "$COUNTER_FILE" ]]; then
      TASK_ID=$(( $(cat "$COUNTER_FILE") + 1 ))
    else
      TASK_ID=1
    fi
    echo "$TASK_ID" > "$COUNTER_FILE"

    # Append task to tasks.md
    echo "- [ ] ${SUBJECT} <!-- task:${TASK_ID} -->" >> "$TASKS_FILE"
    ;;

  TaskUpdate)
    TASK_ID=$(echo "$HOOK_INPUT" | jq -r '.tool_input.taskId // empty' 2>/dev/null || true)
    STATUS=$(echo "$HOOK_INPUT" | jq -r '.tool_input.status // empty' 2>/dev/null || true)

    if [[ -z "$TASK_ID" || -z "$STATUS" || ! -f "$TASKS_FILE" ]]; then
      exit 0
    fi

    case "$STATUS" in
      in_progress)
        # Remove existing active markers
        sed -i '' 's/ status:active//g' "$TASKS_FILE"
        # Add active marker to this task
        sed -i '' "s/<!-- task:${TASK_ID} -->/<!-- task:${TASK_ID} status:active -->/" "$TASKS_FILE"
        ;;
      completed)
        # Mark as done and remove active marker
        sed -i '' "s/- \[ \] \(.*\)<!-- task:${TASK_ID}\( status:active\)\{0,1\} -->/- [x] \1<!-- task:${TASK_ID} -->/" "$TASKS_FILE"
        ;;
      deleted)
        # Remove the task line entirely
        sed -i '' "/<!-- task:${TASK_ID}/d" "$TASKS_FILE"
        ;;
    esac
    ;;
esac

exit 0
