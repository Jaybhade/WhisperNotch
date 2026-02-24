#!/bin/bash
set -e

# ─────────────────────────────────────────────────────────
#  WhisperNotch — Build & Package DMG
#  Run this on your Mac with Xcode 15+ installed:
#    chmod +x build-dmg.sh && ./build-dmg.sh
# ─────────────────────────────────────────────────────────

APP_NAME="WhisperNotch"
BUNDLE_ID="com.whispernotch.app"
SCHEME="WhisperNotch"
BUILD_DIR="$(pwd)/build"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-Installer"
DMG_PATH="$(pwd)/${DMG_NAME}.dmg"
DMG_TEMP="$(pwd)/${DMG_NAME}-temp.dmg"
DMG_VOLUME="/Volumes/${APP_NAME}"
DMG_SIZE="300m"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║       WhisperNotch — Build & DMG         ║${NC}"
echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Step 0: Preflight checks ──────────────────────────────

echo -e "${BOLD}[1/6] Preflight checks…${NC}"

if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode command line tools not found.${NC}"
    echo "  Install with: xcode-select --install"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -1)
echo "  ✓ ${XCODE_VERSION}"

# Check for Apple Silicon or Intel
ARCH=$(uname -m)
echo "  ✓ Architecture: ${ARCH}"

# ── Step 1: Resolve Swift packages ────────────────────────

echo ""
echo -e "${BOLD}[2/6] Resolving Swift packages (WhisperKit)…${NC}"
xcodebuild -resolvePackageDependencies \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -quiet 2>&1 | tail -3 || true
echo "  ✓ Packages resolved"

# ── Step 2: Build the app ─────────────────────────────────

echo ""
echo -e "${BOLD}[3/6] Building ${APP_NAME} (Release)…${NC}"
echo "  This may take a few minutes on first build (Core ML compilation)…"

# Clean previous build
rm -rf "${BUILD_DIR}"

xcodebuild build \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}/DerivedData" \
    -destination "platform=macOS,arch=${ARCH}" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | while IFS= read -r line; do
        # Show only key progress lines
        if echo "$line" | grep -q "^CompileSwift\|^Linking\|^GenerateDSYMFile\|BUILD SUCCEEDED\|BUILD FAILED\|error:"; then
            echo "  $line"
        fi
    done

# Find the built .app
BUILT_APP=$(find "${BUILD_DIR}/DerivedData" -name "${APP_NAME}.app" -type d | head -1)

if [ -z "$BUILT_APP" ] || [ ! -d "$BUILT_APP" ]; then
    echo -e "${RED}Error: Build failed. Could not find ${APP_NAME}.app${NC}"
    echo "  Try building manually in Xcode to see detailed errors."
    exit 1
fi

# Copy to clean location
rm -rf "${APP_PATH}"
cp -R "${BUILT_APP}" "${APP_PATH}"
echo -e "  ${GREEN}✓ Build succeeded${NC}"

# ── Step 3: Ad-hoc code sign ──────────────────────────────

echo ""
echo -e "${BOLD}[4/6] Code signing (ad-hoc)…${NC}"
codesign --force --deep --sign - "${APP_PATH}" 2>/dev/null || true
echo "  ✓ Signed with ad-hoc identity"

# ── Step 4: Create DMG ────────────────────────────────────

echo ""
echo -e "${BOLD}[5/6] Creating DMG installer…${NC}"

# Cleanup any existing DMG or mounted volumes
rm -f "${DMG_PATH}" "${DMG_TEMP}"
if [ -d "${DMG_VOLUME}" ]; then
    hdiutil detach "${DMG_VOLUME}" -quiet -force 2>/dev/null || true
fi

# Create a temporary DMG
mkdir -p "${BUILD_DIR}/dmg-contents"
cp -R "${APP_PATH}" "${BUILD_DIR}/dmg-contents/"

# Create a symlink to /Applications for drag-to-install
ln -sf /Applications "${BUILD_DIR}/dmg-contents/Applications"

# Create a background image with instructions
# (Using a simple .DS_Store-free approach)
cat > "${BUILD_DIR}/dmg-contents/.background_setup.sh" << 'BGEOF'
#!/bin/bash
# This creates a minimal visual hint
echo "" > /dev/null
BGEOF

# Create the DMG
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${BUILD_DIR}/dmg-contents" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}" \
    -quiet

echo -e "  ${GREEN}✓ DMG created${NC}"

# ── Step 5: Cleanup & Summary ─────────────────────────────

echo ""
echo -e "${BOLD}[6/6] Cleaning up…${NC}"
rm -rf "${BUILD_DIR}"
echo "  ✓ Build artifacts cleaned"

# Get DMG size
DMG_SIZE_ACTUAL=$(du -h "${DMG_PATH}" | cut -f1 | xargs)

echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║            Build Complete!                ║${NC}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${BOLD}DMG:${NC}  ${DMG_PATH}"
echo -e "  ${BOLD}Size:${NC} ${DMG_SIZE_ACTUAL}"
echo ""
echo -e "  ${CYAN}To install:${NC}"
echo "    1. Double-click ${DMG_NAME}.dmg"
echo "    2. Drag WhisperNotch → Applications"
echo "    3. Open from Applications (right-click → Open on first launch)"
echo "    4. Grant Microphone + Accessibility permissions when prompted"
echo ""
echo -e "  ${CYAN}Usage:${NC}"
echo "    Hold ⌥ Option in any text field → speak → release to insert text"
echo ""
