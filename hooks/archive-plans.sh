#!/bin/bash
# o-m-cc: Archive existing plan files on session start

set -euo pipefail

PLANS_DIR="${HOME}/.claude/plans"
ARCHIVE_DIR="${PLANS_DIR}/archive"
TODAY=$(date +%Y-%m-%d)
TODAY_ARCHIVE="${ARCHIVE_DIR}/${TODAY}"

# Skip if no plans directory
[[ ! -d "$PLANS_DIR" ]] && exit 0

# Find plan files (exclude archive directory and agent files)
plan_files=$(find "$PLANS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
[[ -z "$plan_files" ]] && exit 0

mkdir -p "$TODAY_ARCHIVE"

archived_count=0
for file in $plan_files; do
  filename=$(basename "$file")

  # Skip agent files
  [[ "$filename" == *"-agent-"* ]] && continue

  # Check file age (archive if older than 1 hour)
  # macOS: stat -f %m, Linux: stat -c %Y
  file_mtime=$(stat -f %m "$file" 2>/dev/null || stat -c %Y "$file" 2>/dev/null)
  file_age=$(($(date +%s) - file_mtime))
  [[ $file_age -lt 3600 ]] && continue

  # Archive with timestamp if file already exists
  target="${TODAY_ARCHIVE}/${filename}"
  if [[ -f "$target" ]]; then
    timestamp=$(date +%H%M%S)
    target="${TODAY_ARCHIVE}/${filename%.md}-${timestamp}.md"
  fi

  cp "$file" "$target"
  ((archived_count++))
done

[[ $archived_count -gt 0 ]] && echo "Archived $archived_count plan file(s) to ${TODAY_ARCHIVE}"
exit 0
