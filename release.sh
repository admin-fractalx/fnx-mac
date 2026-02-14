#!/bin/bash
set -e

VERSION="${1:-1.0}"
BUILD_FOR_RELEASE=1 ./build.sh

APP_DIR="FnX.app"

if [ -z "${SIGNING_IDENTITY}" ]; then
  echo "Set SIGNING_IDENTITY to sign the app (e.g. 'Developer ID Application: Your Name (TEAM_ID)')"
  echo "Skipping code signing."
else
  echo "Signing ${APP_DIR}..."
  codesign --force --options runtime --timestamp -s "${SIGNING_IDENTITY}" "${APP_DIR}/Contents/MacOS/FnX"
  codesign --force --options runtime --timestamp -s "${SIGNING_IDENTITY}" "${APP_DIR}"
  echo "Signed."
fi

ZIP_NAME="FnX-${VERSION}.zip"
rm -f "${ZIP_NAME}"
ditto -c -k --sequesterRsrc --keepParent "${APP_DIR}" "${ZIP_NAME}"
echo "Created ${ZIP_NAME}"

if [ "${NOTARIZE}" = "1" ] && [ -n "${SIGNING_IDENTITY}" ]; then
  echo "Submitting to Apple for notarization..."
  xcrun notarytool submit "${ZIP_NAME}" --keychain-profile "${NOTARY_KEYCHAIN_PROFILE:-AC_PASSWORD}" --wait
  echo "Notarization complete. Upload ${ZIP_NAME} to GitHub Releases (tag v${VERSION})."
else
  echo "Upload this file to GitHub Releases (tag v${VERSION})"
  [ -z "${SIGNING_IDENTITY}" ] && echo "For Gatekeeper: sign and optionally set NOTARIZE=1 and NOTARY_KEYCHAIN_PROFILE for notarization."
fi
