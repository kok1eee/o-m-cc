#!/bin/bash
# o-m-cc: Update plugin with optional cache clear
# Usage: ./update.sh [--clean]
#
# --clean: Clear cache before reinstall (for cache-related issues)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PLUGIN_NAME="o-m-cc"
MARKETPLACE="kok1eee"
CACHE_DIR="${HOME}/.claude/plugins/cache/${MARKETPLACE}/${PLUGIN_NAME}"

echo -e "${GREEN}=== o-m-cc Update ===${NC}"

# Check for --clean flag
CLEAN_INSTALL=false
for arg in "$@"; do
  case $arg in
    --clean|-c)
      CLEAN_INSTALL=true
      ;;
  esac
done

if $CLEAN_INSTALL; then
  echo -e "${YELLOW}Clean install mode${NC}"

  # Uninstall
  echo "  📦 Uninstalling ${PLUGIN_NAME}..."
  claude plugin uninstall "${PLUGIN_NAME}@${MARKETPLACE}" 2>/dev/null || true

  # Clear cache
  if [[ -d "$CACHE_DIR" ]]; then
    echo "  🗑️  Clearing cache: ${CACHE_DIR}"
    rm -rf "$CACHE_DIR"
  fi

  # Reinstall
  echo "  📦 Installing ${PLUGIN_NAME}..."
  claude plugin install "${PLUGIN_NAME}@${MARKETPLACE}"
else
  # Standard update
  echo "  📦 Updating ${PLUGIN_NAME}..."
  claude plugin update "${PLUGIN_NAME}@${MARKETPLACE}"
fi

echo ""
echo -e "${GREEN}✅ Update complete${NC}"
echo -e "${YELLOW}⚠️  Restart Claude Code to apply changes${NC}"
