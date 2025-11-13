#!/usr/bin/env bash

#######################################
# SDK Generator Setup Script
#
# This script installs all dependencies
# needed to generate SDKs
#######################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      SDK Generator Setup                     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════╝${NC}"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${YELLOW}⚠ Node.js not found${NC}"
    echo ""
    echo "Please install Node.js 16+ to continue:"
    echo "  - macOS: brew install node"
    echo "  - Ubuntu: sudo apt install nodejs npm"
    echo "  - Windows: Download from https://nodejs.org"
    echo ""
    exit 1
fi

NODE_VERSION=$(node -v)
echo -e "${GREEN}✓ Node.js installed: $NODE_VERSION${NC}"

# Check npm
if ! command -v npm &> /dev/null; then
    echo -e "${YELLOW}⚠ npm not found${NC}"
    echo "Please install npm to continue"
    exit 1
fi

NPM_VERSION=$(npm -v)
echo -e "${GREEN}✓ npm installed: $NPM_VERSION${NC}"
echo ""

# Install OpenAPI Generator CLI
echo -e "${BLUE}Installing OpenAPI Generator CLI...${NC}"
cd sdk
npm install

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Setup complete!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Place your OpenAPI spec at: sdk/openapi.yaml"
    echo "  2. Run: ./sdk/generate.sh -o swagger.yml"
    echo ""
    echo "Or run the configuration wizard:"
    echo "  ./sdk/generate.sh -c"
    echo ""
else
    echo -e "${YELLOW}⚠ Installation had issues. Please check the errors above.${NC}"
    exit 1
fi

