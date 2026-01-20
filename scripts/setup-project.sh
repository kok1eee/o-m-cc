#!/bin/bash
# o-m-cc: Setup Standards and Steering directories
# Usage: ./setup-project.sh [--standards] [--steering] [--all]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="${PLUGIN_ROOT}/templates"
TARGET_DIR="${PWD}/spec"

# Flags
SETUP_STANDARDS=false
SETUP_STEERING=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --standards)
      SETUP_STANDARDS=true
      shift
      ;;
    --steering)
      SETUP_STEERING=true
      shift
      ;;
    --all)
      SETUP_STANDARDS=true
      SETUP_STEERING=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [--standards] [--steering] [--all]"
      echo ""
      echo "Options:"
      echo "  --standards  Setup standards directory"
      echo "  --steering   Setup steering directory"
      echo "  --all        Setup both standards and steering"
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

# Default to all if no flags specified
if [[ "$SETUP_STANDARDS" == false && "$SETUP_STEERING" == false ]]; then
  SETUP_STANDARDS=true
  SETUP_STEERING=true
fi

echo -e "${GREEN}=== o-m-cc Project Setup ===${NC}"
echo -e "${BLUE}Target: ${TARGET_DIR}${NC}"
echo ""

# Ensure spec directory exists
mkdir -p "$TARGET_DIR"

# Setup Standards
if [[ "$SETUP_STANDARDS" == true ]]; then
  echo -e "${YELLOW}Setting up Standards...${NC}"

  STANDARDS_DIR="${TARGET_DIR}/standards"
  LEARNED_DIR="${STANDARDS_DIR}/learned"

  if [[ -d "$STANDARDS_DIR" ]]; then
    echo -e "${BLUE}  Standards directory already exists${NC}"
    # Check if learned/ exists, create if missing
    if [[ ! -d "$LEARNED_DIR" ]]; then
      cp -r "${TEMPLATES_DIR}/standards/learned" "$LEARNED_DIR"
      echo -e "${GREEN}  ✅ Added learned/ directory for discovered patterns${NC}"
    else
      echo -e "${BLUE}  Skipping to avoid overwriting existing files${NC}"
    fi
  else
    cp -r "${TEMPLATES_DIR}/standards" "$STANDARDS_DIR"
    echo -e "${GREEN}  ✅ Standards created: ${STANDARDS_DIR}${NC}"
    echo -e "     - global/coding-style.md"
    echo -e "     - global/conventions.md"
    echo -e "     - global/tech-stack.md"
    echo -e "     - frontend/components.md"
    echo -e "     - backend/api-design.md"
    echo -e "     - testing/test-strategy.md"
    echo -e "     - learned/ (発見したパターン)"
  fi
  echo ""
fi

# Setup Steering
if [[ "$SETUP_STEERING" == true ]]; then
  echo -e "${YELLOW}Setting up Steering...${NC}"

  STEERING_DIR="${TARGET_DIR}/steering"

  if [[ -d "$STEERING_DIR" ]]; then
    echo -e "${BLUE}  Steering directory already exists${NC}"
    echo -e "${BLUE}  Skipping to avoid overwriting existing files${NC}"
  else
    cp -r "${TEMPLATES_DIR}/steering" "$STEERING_DIR"
    echo -e "${GREEN}  ✅ Steering created: ${STEERING_DIR}${NC}"
    echo -e "     - product.md  (プロダクト文脈)"
    echo -e "     - tech.md     (技術アーキテクチャ)"
    echo -e "     - structure.md (プロジェクト構造)"
  fi
  echo ""
fi

echo -e "${GREEN}=== Setup complete ===${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Edit files in spec/standards/ to match your project's coding standards"
echo -e "  2. Edit files in spec/steering/ to describe your project context"
echo -e "  3. Run '/o-m-cc:init' to enable Sisyphus mode"
