#!/bin/bash
# Sync TaskCreate/TaskUpdate to spec/plan/tasks.md
# PostToolUse (TaskCreate|TaskUpdate) で実行
# cc-sidebar がこのファイルを監視して進捗表示する

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  sed_inplace() { sed -i '' "$1" "$2" 2>/dev/null || sed -i "$1" "$2"; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
  check_command() { command -v "$1" >/dev/null 2>&1; }
fi

TASKS_FILE="spec/plan/tasks.md"
COUNTER_FILE="spec/.task-counter"

# Read hook input
HOOK_INPUT=$(cat)

# jq がない場合はスキップ
if ! check_command jq; then
  log_debug "jq がインストールされていないためスキップ"
  exit 0
fi

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
      TASK_ID=$(cat "$COUNTER_FILE")
      TASK_ID=$((TASK_ID + 1))
    else
      TASK_ID=1
    fi
    echo "$TASK_ID" > "$COUNTER_FILE"

    # Append task to tasks.md
    echo "- [ ] ${SUBJECT} <!-- task:${TASK_ID} -->" >> "$TASKS_FILE"
    log_debug "タスク追加: ${SUBJECT} (ID: ${TASK_ID})"
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
        sed_inplace 's/ status:active//g' "$TASKS_FILE"
        # Add active marker to this task
        sed_inplace "s/<!-- task:${TASK_ID} -->/<!-- task:${TASK_ID} status:active -->/" "$TASKS_FILE"
        log_debug "タスク開始: ID ${TASK_ID}"
        ;;
      completed)
        # Mark as done and remove active marker
        sed_inplace "s/- \[ \] \(.*\)<!-- task:${TASK_ID}\( status:active\)\{0,1\} -->/- [x] \1<!-- task:${TASK_ID} -->/" "$TASKS_FILE"
        log_debug "タスク完了: ID ${TASK_ID}"
        ;;
      deleted)
        # Remove the task line entirely
        sed_inplace "/<!-- task:${TASK_ID}/d" "$TASKS_FILE"
        log_debug "タスク削除: ID ${TASK_ID}"
        ;;
    esac
    ;;
esac

exit 0
