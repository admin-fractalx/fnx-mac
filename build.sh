#!/bin/bash
set -e

echo "Building FnX..."
swift build -c release

APP_NAME="FnX"
BUILD_DIR=".build/release"
APP_DIR="${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

# Clean previous build
rm -rf "${APP_DIR}"

# Create .app bundle structure
mkdir -p "${MACOS_DIR}"

# Copy binary
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"

# Copy Info.plist
cp "Info.plist" "${CONTENTS_DIR}/Info.plist"

# Copy SPM resource bundles (contains whisper model)
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
mkdir -p "${RESOURCES_DIR}"
for bundle in "${BUILD_DIR}"/*.bundle; do
    if [ -d "$bundle" ]; then
        cp -R "$bundle" "${RESOURCES_DIR}/"
        echo "  Copied resource: $(basename $bundle)"
    fi
done

# Reset onboarding so it shows on next launch (skip when building for release)
if [ -z "${BUILD_FOR_RELEASE}" ]; then
  defaults delete com.fnx.app fnx_onboarding_completed 2>/dev/null || true
fi

echo "Built ${APP_DIR} successfully!"
echo ""
echo "To run: open ${APP_DIR}"
echo ""
echo "Note: You'll need to grant the following permissions in System Settings:"
echo "  - Privacy & Security → Microphone → FnX"
echo "  - Privacy & Security → Accessibility → FnX"
echo "  - Privacy & Security → Input Monitoring → FnX"
