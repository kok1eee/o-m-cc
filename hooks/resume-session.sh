#!/bin/bash
# o-m-cc: Resume session from handoff.yaml on session start

set -euo pipefail

HANDOFF_FILE="spec/plan/handoff.yaml"

# Skip if no handoff file
[[ ! -f "$HANDOFF_FILE" ]] && exit 0

# Check file age (skip if older than 7 days)
file_mtime=$(stat -f %m "$HANDOFF_FILE" 2>/dev/null || stat -c %Y "$HANDOFF_FILE" 2>/dev/null)
file_age_days=$(( ($(date +%s) - file_mtime) / 86400 ))
[[ $file_age_days -gt 7 ]] && exit 0

# Display previous session state
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 Previous Session Found (spec/plan/handoff.yaml)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract key information using grep/sed (lightweight parsing)
if grep -q "status:" "$HANDOFF_FILE"; then
  status=$(grep "^status:" "$HANDOFF_FILE" | head -1 | sed 's/status: *//' | tr -d '"')
  echo "Status: $status"
fi

if grep -q "current_task:" "$HANDOFF_FILE"; then
  echo ""
  echo "Current Task:"
  # Extract task id if exists
  task_id=$(grep -A1 "current_task:" "$HANDOFF_FILE" | grep "id:" | head -1 | sed 's/.*id: *//' | tr -d '"' || echo "")
  task_name=$(grep -A2 "current_task:" "$HANDOFF_FILE" | grep "name:" | head -1 | sed 's/.*name: *//' | tr -d '"' || echo "")
  [[ -n "$task_id" ]] && echo "  - ID: $task_id"
  [[ -n "$task_name" ]] && echo "  - Name: $task_name"
fi

if grep -q "next_steps:" "$HANDOFF_FILE"; then
  echo ""
  echo "Next Steps:"
  # Extract next steps (lines starting with - after next_steps:)
  sed -n '/^next_steps:/,/^[a-z_]*:/p' "$HANDOFF_FILE" | grep "^  - " | head -5 | sed 's/^  //'
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 To continue: describe what you want to work on"
echo "💡 To start fresh: /clear"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
