#!/bin/bash

# Notarization script for Cookbook Mac app
# This script builds, exports, notarizes, and packages the app for distribution

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/Cookbook.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
APP_PATH="$EXPORT_PATH/Cookbook.app"
ZIP_PATH="$BUILD_DIR/Cookbook.zip"
DMG_PATH="$BUILD_DIR/Cookbook.dmg"

SCHEME="Cookbook"
PROJECT="$PROJECT_DIR/Cookbook.xcodeproj"
EXPORT_OPTIONS="$PROJECT_DIR/exportOptions.plist"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must run on macOS${NC}"
    exit 1
fi

echo -e "${GREEN}Cookbook Notarization Script${NC}"
echo "================================"

# Check for required credentials
if [ -z "$NOTARIZATION_APPLE_ID" ]; then
    echo -e "${YELLOW}Warning: NOTARIZATION_APPLE_ID not set${NC}"
    echo "Please set environment variables:"
    echo "  export NOTARIZATION_APPLE_ID='your@email.com'"
    echo "  export NOTARIZATION_PASSWORD='xxxx-xxxx-xxxx-xxxx'"
    echo "  export NOTARIZATION_TEAM_ID='63KWA2RPU8'"
    echo ""
    read -p "Enter Apple ID: " NOTARIZATION_APPLE_ID
    read -s -p "Enter App-Specific Password: " NOTARIZATION_PASSWORD
    echo ""
    NOTARIZATION_TEAM_ID="${NOTARIZATION_TEAM_ID:-63KWA2RPU8}"
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Step 1: Build and Archive
echo -e "${GREEN}Step 1: Building and archiving...${NC}"
xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="63KWA2RPU8" \
    CODE_SIGN_IDENTITY="Apple Development" \
    | xcpretty || true

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}Error: Archive failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Archive created successfully${NC}"

# Step 2: Export Archive
echo -e "${GREEN}Step 2: Exporting archive...${NC}"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    | xcpretty || true

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Export failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ App exported successfully${NC}"

# Step 3: Create ZIP for Notarization
echo -e "${GREEN}Step 3: Creating ZIP archive...${NC}"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [ ! -f "$ZIP_PATH" ]; then
    echo -e "${RED}Error: ZIP creation failed${NC}"
    exit 1
fi

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo -e "${GREEN}✓ ZIP created: $ZIP_SIZE${NC}"

# Step 4: Submit for Notarization
echo -e "${GREEN}Step 4: Submitting for notarization...${NC}"
echo -e "${YELLOW}This may take several minutes...${NC}"

SUBMISSION_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$NOTARIZATION_APPLE_ID" \
    --password "$NOTARIZATION_PASSWORD" \
    --team-id "${NOTARIZATION_TEAM_ID:-63KWA2RPU8}" \
    --wait 2>&1)

echo "$SUBMISSION_OUTPUT"

if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓ Notarization succeeded!${NC}"

    # Extract submission ID for logging
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    echo "Submission ID: $SUBMISSION_ID"

    # Step 5: Staple the Notarization
    echo -e "${GREEN}Step 5: Stapling notarization ticket...${NC}"
    xcrun stapler staple "$APP_PATH"

    if xcrun stapler validate "$APP_PATH" | grep -q "The validate action worked"; then
        echo -e "${GREEN}✓ Notarization ticket stapled successfully${NC}"
    else
        echo -e "${YELLOW}Warning: Stapling validation unclear${NC}"
    fi

    # Step 6: Create DMG
    echo -e "${GREEN}Step 6: Creating DMG...${NC}"
    rm -f "$DMG_PATH"
    hdiutil create -volname "Cookbook" \
        -srcfolder "$APP_PATH" \
        -ov -format UDZO \
        "$DMG_PATH"

    if [ -f "$DMG_PATH" ]; then
        DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
        echo -e "${GREEN}✓ DMG created: $DMG_SIZE${NC}"

        # Verify the DMG
        echo -e "${GREEN}Verifying distribution package...${NC}"
        spctl -a -vvv -t install "$APP_PATH" || echo -e "${YELLOW}Warning: spctl check failed (may need Developer ID cert)${NC}"
    fi

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}SUCCESS! Distribution packages ready:${NC}"
    echo "  App:  $APP_PATH"
    echo "  ZIP:  $ZIP_PATH"
    echo "  DMG:  $DMG_PATH"
    echo ""
    echo "Next steps:"
    echo "  1. Test the app on a different Mac"
    echo "  2. Distribute the DMG to users"
    echo "  3. Users can drag app to Applications folder"

elif echo "$SUBMISSION_OUTPUT" | grep -q "status: Invalid"; then
    echo -e "${RED}✗ Notarization failed${NC}"

    # Try to get detailed log
    SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep "id:" | head -1 | awk '{print $2}')
    if [ -n "$SUBMISSION_ID" ]; then
        echo -e "${YELLOW}Fetching notarization log...${NC}"
        xcrun notarytool log "$SUBMISSION_ID" \
            --apple-id "$NOTARIZATION_APPLE_ID" \
            --password "$NOTARIZATION_PASSWORD" \
            --team-id "${NOTARIZATION_TEAM_ID:-63KWA2RPU8}"
    fi

    exit 1
else
    echo -e "${RED}✗ Notarization status unknown${NC}"
    echo "Full output:"
    echo "$SUBMISSION_OUTPUT"
    exit 1
fi

# Step 7: Quick Distribution Package (Non-Notarized for Testing)
echo ""
echo -e "${YELLOW}Creating quick distribution package (for testing only)...${NC}"
QUICK_ZIP="$BUILD_DIR/Cookbook-quick-test.zip"
ditto -c -k --keepParent "$APP_PATH" "$QUICK_ZIP"
echo -e "${GREEN}✓ Test package: $QUICK_ZIP${NC}"
echo -e "${YELLOW}⚠ Test recipients must run: xattr -cr /path/to/Cookbook.app${NC}"
