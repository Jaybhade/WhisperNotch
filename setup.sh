#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────
#  WhisperNotch — Project Setup
#  Generates the .xcodeproj using XcodeGen
# ─────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}WhisperNotch — Project Setup${NC}"
echo ""

# Step 1: Check/install XcodeGen
if command -v xcodegen &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} XcodeGen found: $(xcodegen --version 2>&1 | head -1)"
else
    echo -e "  ${CYAN}Installing XcodeGen via Homebrew…${NC}"
    if ! command -v brew &> /dev/null; then
        echo -e "${RED}Error: Homebrew not found. Install it from https://brew.sh${NC}"
        echo "  Then re-run this script."
        exit 1
    fi
    brew install xcodegen
    echo -e "  ${GREEN}✓${NC} XcodeGen installed"
fi

# Step 2: Generate the Xcode project
echo ""
echo -e "  ${BOLD}Generating WhisperNotch.xcodeproj…${NC}"
cd "$(dirname "$0")"
xcodegen generate

echo ""
echo -e "${GREEN}${BOLD}Done!${NC} Now open the project:"
echo ""
echo -e "  ${CYAN}open WhisperNotch.xcodeproj${NC}"
echo ""
echo "  Xcode will resolve the WhisperKit package automatically."
echo "  Select the WhisperNotch scheme → My Mac → ⌘R to build & run."
echo ""
