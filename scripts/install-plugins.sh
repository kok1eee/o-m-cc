#!/bin/bash
# o-m-cc: Install recommended plugins
# Usage: ./install-plugins.sh [--ts] [--py] [--go] [--rust] [--all]
#
# Note: security-guidance and code-simplifier are now integrated into o-m-cc
# (via hooks and agents respectively)

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== o-m-cc Plugin Installer ===${NC}"

# Add marketplace (if not already added)
echo -e "${YELLOW}Adding marketplace...${NC}"
claude plugin marketplace add anthropics/claude-plugins-official 2>/dev/null || true

# Common plugins (always install)
# Note: security-guidance is now integrated via hooks/security_reminder_hook.py
# Note: code-simplifier is now integrated via agents/code-simplifier.md
echo -e "${YELLOW}Installing common plugins...${NC}"
for plugin in frontend-design feature-dev; do
  if claude plugin list 2>/dev/null | grep -q "$plugin"; then
    echo "  ✅ $plugin (already installed)"
  else
    echo "  📦 Installing $plugin..."
    claude plugin install "$plugin" 2>/dev/null || echo "  ⚠️  Failed to install $plugin"
  fi
done

echo -e "${CYAN}  ℹ️  security-guidance: integrated into o-m-cc (hooks)${NC}"
echo -e "${CYAN}  ℹ️  code-simplifier: integrated into o-m-cc (agents)${NC}"

# Parse arguments for LSP plugins
INSTALL_TS=false
INSTALL_PY=false
INSTALL_GO=false
INSTALL_RUST=false

for arg in "$@"; do
  case $arg in
    --ts|--typescript|--js|--javascript|--react)
      INSTALL_TS=true
      ;;
    --py|--python)
      INSTALL_PY=true
      ;;
    --go|--golang)
      INSTALL_GO=true
      ;;
    --rust|--rs)
      INSTALL_RUST=true
      ;;
    --all)
      INSTALL_TS=true
      INSTALL_PY=true
      INSTALL_GO=true
      INSTALL_RUST=true
      ;;
  esac
done

# Install LSP plugins based on selection
echo -e "${YELLOW}Installing LSP plugins...${NC}"

if $INSTALL_TS; then
  if claude plugin list 2>/dev/null | grep -q "vtsls"; then
    echo "  ✅ vtsls (already installed)"
  else
    echo "  📦 Installing vtsls (TypeScript/JS)..."
    claude plugin install vtsls 2>/dev/null || echo "  ⚠️  Failed to install vtsls"
  fi
fi

if $INSTALL_PY; then
  if claude plugin list 2>/dev/null | grep -q "pyright"; then
    echo "  ✅ pyright (already installed)"
  else
    echo "  📦 Installing pyright (Python)..."
    claude plugin install pyright 2>/dev/null || echo "  ⚠️  Failed to install pyright"
  fi
fi

if $INSTALL_GO; then
  if claude plugin list 2>/dev/null | grep -q "gopls"; then
    echo "  ✅ gopls (already installed)"
  else
    echo "  📦 Installing gopls (Go)..."
    claude plugin install gopls 2>/dev/null || echo "  ⚠️  Failed to install gopls"
  fi
fi

if $INSTALL_RUST; then
  if claude plugin list 2>/dev/null | grep -q "rust-analyzer"; then
    echo "  ✅ rust-analyzer (already installed)"
  else
    echo "  📦 Installing rust-analyzer (Rust)..."
    claude plugin install rust-analyzer 2>/dev/null || echo "  ⚠️  Failed to install rust-analyzer"
  fi
fi

if ! $INSTALL_TS && ! $INSTALL_PY && ! $INSTALL_GO && ! $INSTALL_RUST; then
  echo "  ⏭️  No LSP selected (use --ts, --py, --go, --rust, or --all)"
fi

echo -e "${GREEN}=== Installation complete ===${NC}"
