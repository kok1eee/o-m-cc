#!/bin/bash
# o-m-cc: Install recommended plugins
# Usage: ./install-plugins.sh [--ts] [--py] [--go] [--rust] [--all]

set -euo pipefail

echo "=== o-m-cc Plugin Installer ==="

# Helper function to check if plugin is installed
is_installed() {
  claude plugin list 2>/dev/null | grep -q "$1"
}

# Helper function to check if marketplace is added
has_marketplace() {
  claude plugin marketplace list 2>/dev/null | grep -q "$1"
}

# Add marketplace (if not already added)
if has_marketplace "claude-plugins-official"; then
  echo "  ✅ Marketplace: claude-plugins-official (already added)"
else
  echo "  📦 Adding marketplace: claude-plugins-official..."
  claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true
fi

# Common plugins
echo ""
echo "Common plugins:"
for plugin in frontend-design feature-dev; do
  if is_installed "$plugin"; then
    echo "  ✅ $plugin (already installed)"
  else
    echo "  📦 Installing $plugin..."
    claude plugin install "$plugin" 2>/dev/null || echo "  ⚠️  Failed: $plugin"
  fi
done
echo "  ℹ️  security-guidance: integrated into o-m-cc (hooks)"
echo "  ℹ️  code-simplifier: integrated into o-m-cc (agents)"

# Parse arguments for LSP plugins
INSTALL_TS=false
INSTALL_PY=false
INSTALL_GO=false
INSTALL_RUST=false

for arg in "$@"; do
  case $arg in
    --ts|--typescript|--js|--javascript|--react) INSTALL_TS=true ;;
    --py|--python) INSTALL_PY=true ;;
    --go|--golang) INSTALL_GO=true ;;
    --rust|--rs) INSTALL_RUST=true ;;
    --all) INSTALL_TS=true; INSTALL_PY=true; INSTALL_GO=true; INSTALL_RUST=true ;;
  esac
done

# Install LSP plugins based on selection
echo ""
echo "LSP plugins:"

install_lsp() {
  local plugin=$1
  local lang=$2
  if is_installed "$plugin"; then
    echo "  ✅ $plugin ($lang) - already installed"
  else
    echo "  📦 Installing $plugin ($lang)..."
    claude plugin install "$plugin" 2>/dev/null || echo "  ⚠️  Failed: $plugin"
  fi
}

$INSTALL_TS && install_lsp "vtsls" "TypeScript/JS"
$INSTALL_PY && install_lsp "pyright" "Python"
$INSTALL_GO && install_lsp "gopls" "Go"
$INSTALL_RUST && install_lsp "rust-analyzer" "Rust"

if ! $INSTALL_TS && ! $INSTALL_PY && ! $INSTALL_GO && ! $INSTALL_RUST; then
  echo "  ⏭️  No LSP selected (use --ts, --py, --go, --rust, or --all)"
fi

echo ""
echo "=== Done ==="
