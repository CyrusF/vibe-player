#!/usr/bin/env bash
set -euo pipefail

APP_NAME="VibePlayer"
PRODUCT_NAME="VibePlayer"
BUNDLE_ID="dev.local.vibeplayer"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
APP_BUNDLE="${DIST_DIR}/${APP_NAME}.app"
EXECUTABLE_PATH="${ROOT_DIR}/.build/debug/${PRODUCT_NAME}"

MODE="${1:-}"

cd "${ROOT_DIR}"

if pgrep -x "${APP_NAME}" >/dev/null 2>&1; then
  pkill -x "${APP_NAME}" || true
  sleep 0.4
fi

swift build --product "${PRODUCT_NAME}"

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${ROOT_DIR}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
cp "${ROOT_DIR}/Resources/StatusBarTemplate.png" "${APP_BUNDLE}/Contents/Resources/StatusBarTemplate.png"

cat > "${APP_BUNDLE}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Vibe Player controls only the browser video tab you select.</string>
  <key>NSCameraUsageDescription</key>
  <string>Vibe Player uses the camera locally to detect whether you are looking at your playback screen.</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

case "${MODE}" in
  --debug)
    lldb "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
    ;;
  --logs)
    /usr/bin/open -n "${APP_BUNDLE}"
    /usr/bin/log stream --style compact --predicate "process == '${APP_NAME}'"
    ;;
  --telemetry)
    /usr/bin/open -n "${APP_BUNDLE}"
    /usr/bin/log stream --info --style compact --predicate "subsystem == 'dev.local.vibeplayer'"
    ;;
  --verify)
    /usr/bin/open -n "${APP_BUNDLE}"
    sleep 1.5
    pgrep -x "${APP_NAME}" >/dev/null
    echo "${APP_NAME} launched."
    ;;
  "")
    /usr/bin/open -n "${APP_BUNDLE}"
    ;;
  *)
    echo "Unknown option: ${MODE}" >&2
    exit 64
    ;;
esac
