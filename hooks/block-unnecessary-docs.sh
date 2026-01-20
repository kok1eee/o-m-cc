#!/bin/bash
# o-m-cc: Block unnecessary markdown file creation
# PreToolUse hook for Write tool
#
# Allows: README.md, CLAUDE.md, CONTRIBUTING.md, CHANGELOG.md
# Also allows: files in spec/standards/, spec/steering/, docs/, documentation/ directories

set -euo pipefail

# Read tool input from stdin
INPUT=$(cat)

# Extract file path from JSON input
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | sed 's/"file_path"\s*:\s*"//;s/"$//' || echo "")

# If no file path, allow (not our concern)
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Check if it's a markdown file
if [[ ! "$FILE_PATH" =~ \.md$ ]] && [[ ! "$FILE_PATH" =~ \.mdx$ ]]; then
  exit 0
fi

# Extract filename
FILENAME=$(basename "$FILE_PATH")

# Allowed markdown files (case-insensitive check)
FILENAME_LOWER=$(echo "$FILENAME" | tr '[:upper:]' '[:lower:]')
ALLOWED_FILES=(
  "readme.md"
  "claude.md"
  "contributing.md"
  "changelog.md"
  "license.md"
)

for allowed in "${ALLOWED_FILES[@]}"; do
  if [[ "$FILENAME_LOWER" == "$allowed" ]]; then
    exit 0
  fi
done

# Allowed directories (files in these directories are allowed)
ALLOWED_DIRS=(
  "spec/standards/"
  "spec/steering/"
  "spec/plan/"
  "docs/"
  "documentation/"
  ".github/"
)

for dir in "${ALLOWED_DIRS[@]}"; do
  if [[ "$FILE_PATH" == *"$dir"* ]]; then
    exit 0
  fi
done

# Block with warning message
echo "BLOCKED: Creating ${FILENAME} is not allowed."
echo "Allowed markdown files: README.md, CLAUDE.md, CONTRIBUTING.md, CHANGELOG.md"
echo "Allowed directories: spec/standards/, spec/steering/, spec/plan/, docs/, documentation/, .github/"
echo "If this is intentional, ask the user for explicit permission."
exit 2
