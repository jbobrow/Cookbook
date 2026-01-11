#!/bin/bash

# Quick Test Build Script
# Creates a development build for testing on other Macs (requires manual quarantine removal)

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build-test"
APP_NAME="Cookbook.app"

echo -e "${GREEN}Building Cookbook for Testing${NC}"
echo "=============================="

# Clean
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build
echo -e "${GREEN}Building app...${NC}"
xcodebuild \
    -project "$PROJECT_DIR/Cookbook.xcodeproj" \
    -scheme Cookbook \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="63KWA2RPU8" \
    | xcpretty || true

# Find the built app
BUILT_APP=$(find "$BUILD_DIR/DerivedData/Build/Products/Release" -name "$APP_NAME" -type d | head -1)

if [ -z "$BUILT_APP" ]; then
    echo "Error: Could not find built app"
    exit 1
fi

# Copy to build directory
cp -R "$BUILT_APP" "$BUILD_DIR/"

# Create ZIP
echo -e "${GREEN}Creating test package...${NC}"
cd "$BUILD_DIR"
ditto -c -k --keepParent "$APP_NAME" "Cookbook-test.zip"

ZIP_SIZE=$(du -h "Cookbook-test.zip" | cut -f1)
echo ""
echo -e "${GREEN}✓ Test build complete!${NC}"
echo "  Package: $BUILD_DIR/Cookbook-test.zip ($ZIP_SIZE)"
echo ""
echo -e "${YELLOW}IMPORTANT: Recipients must remove quarantine attribute:${NC}"
echo "  1. Extract the ZIP"
echo "  2. Run in Terminal:"
echo "     xattr -cr /path/to/Cookbook.app"
echo "  3. Double-click to open"
echo ""
echo -e "${YELLOW}Note: This is for TESTING ONLY${NC}"
echo "For production distribution, use ./scripts/notarize.sh"
