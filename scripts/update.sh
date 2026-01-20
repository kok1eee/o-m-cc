#!/bin/bash
# o-m-cc: Clean update (uninstall → cache clear → reinstall)
# Usage: ./update.sh

set -euo pipefail

PLUGIN_NAME="o-m-cc"
MARKETPLACE="kok1eee"
CACHE_DIR="${HOME}/.claude/plugins/cache/${MARKETPLACE}/${PLUGIN_NAME}"

echo "=== o-m-cc Clean Update ==="

# Uninstall
echo "  📦 Uninstalling ${PLUGIN_NAME}..."
claude plugin uninstall "${PLUGIN_NAME}@${MARKETPLACE}" 2>/dev/null || true

# Clear cache
if [[ -d "$CACHE_DIR" ]]; then
  echo "  🗑️  Clearing cache..."
  rm -rf "$CACHE_DIR"
fi

# Reinstall
echo "  📦 Installing ${PLUGIN_NAME}..."
claude plugin install "${PLUGIN_NAME}@${MARKETPLACE}"

echo ""
echo "✅ o-m-cc をクリーンインストールしました"
echo "⚠️  Claude Code を再起動してください"
