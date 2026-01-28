#!/bin/bash
# o-m-cc: Warn about console.log in JS/TS files
# PostToolUse hook for Edit/Write tools
#
# Detects console.log, console.debug, console.info statements
# Shows warning but does NOT block (exit 0)

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  log_debug() { :; }
fi

# Read tool output from stdin
INPUT=$(cat)

# Extract file path from JSON input
FILE_PATH=$(echo "$INPUT" | grep -oE '"file_path"\s*:\s*"[^"]*"' | sed 's/"file_path"\s*:\s*"//;s/"$//' || echo "")

# If no file path, skip
if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

# Only check JS/TS files
if [[ ! "$FILE_PATH" =~ \.(js|jsx|ts|tsx|mjs|cjs)$ ]]; then
  exit 0
fi

# Skip test files
if [[ "$FILE_PATH" =~ \.(test|spec)\.(js|jsx|ts|tsx)$ ]] || [[ "$FILE_PATH" =~ /__tests__/ ]]; then
  exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Search for console statements
CONSOLE_MATCHES=$(grep -n "console\.\(log\|debug\|info\|warn\|error\)" "$FILE_PATH" 2>/dev/null || true)

if [[ -n "$CONSOLE_MATCHES" ]]; then
  echo ""
  echo "WARNING: console statements detected in ${FILE_PATH}:"
  echo "$CONSOLE_MATCHES" | head -5

  MATCH_COUNT=$(echo "$CONSOLE_MATCHES" | wc -l | tr -d ' ')
  if [[ "$MATCH_COUNT" -gt 5 ]]; then
    echo "  ... and $((MATCH_COUNT - 5)) more"
  fi

  echo ""
  echo "Consider removing debug statements before committing."
fi

# Always exit 0 (warning only, no block)
exit 0
