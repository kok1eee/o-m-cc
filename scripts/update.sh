#!/bin/bash
# o-m-cc: Update plugin (keeps old version for session compatibility)
# Usage: ./update.sh

set -euo pipefail

PLUGIN_NAME="o-m-cc"
MARKETPLACE="kok1eee"
CACHE_DIR="${HOME}/.claude/plugins/cache/${MARKETPLACE}/${PLUGIN_NAME}"

echo "=== o-m-cc Update ==="

# Get current version before update
OLD_VERSION=""
if [[ -d "$CACHE_DIR" ]]; then
  OLD_VERSION=$(ls -1 "$CACHE_DIR" 2>/dev/null | sort -V | tail -1)
  echo "  Current version: ${OLD_VERSION:-none}"
fi

# Update plugin (this will add new version, may delete old)
echo "  📦 Updating ${PLUGIN_NAME}..."
claude plugin update "${PLUGIN_NAME}@${MARKETPLACE}" 2>&1 || true

# Get new version
NEW_VERSION=""
if [[ -d "$CACHE_DIR" ]]; then
  NEW_VERSION=$(ls -1 "$CACHE_DIR" 2>/dev/null | sort -V | tail -1)
fi

echo ""
if [[ "$OLD_VERSION" != "$NEW_VERSION" ]]; then
  echo "✅ Updated: ${OLD_VERSION} → ${NEW_VERSION}"
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "  ⚠️  セッションの再スタートが必要です"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "  hooks のパスが古いバージョンを参照しています。"
  echo ""
  echo "  👉 /clear で新しいセッションを開始"
  echo "  👉 または Cmd+Shift+P → Reload Window"
  echo ""
  echo "════════════════════════════════════════════════════════"
else
  echo "✅ Already at latest version: ${NEW_VERSION}"
fi
