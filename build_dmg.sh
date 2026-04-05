#!/bin/bash

set -euo pipefail

EXECUTABLE_NAME="${EXECUTABLE_NAME:-FluentApp}"
APP_BUNDLE_NAME="${APP_BUNDLE_NAME:-Fluent App}"
DISPLAY_NAME="${DISPLAY_NAME:-Fluent App}"
ARTIFACT_STEM="${ARTIFACT_STEM:-Fluent-App}"
APP_IDENTIFIER="${APP_IDENTIFIER:-com.alfonsobries.fluent}"
VERSION="${VERSION:-$(cat version.txt 2>/dev/null || echo 1.2.0)}"
# Derive build number from version (1.6.0 → 10600) for Sparkle version comparison
IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$VERSION"
BUILD_NUMBER="${BUILD_NUMBER:-$(( ${V_MAJOR:-0} * 10000 + ${V_MINOR:-0} * 100 + ${V_PATCH:-0} ))}"
APP_BUNDLE="$APP_BUNDLE_NAME.app"
DMG_NAME="${ARTIFACT_STEM}-${VERSION}.dmg"
RESOURCES_DIR="Resources"
ICON_FILE=""
SWIFT_BUILD_ARGS=(-c release)
if [[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]; then
  SIGNING_IDENTITY="$DEVELOPER_ID_APPLICATION"
else
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)"
  SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
fi

echo "Building $DISPLAY_NAME $VERSION ($BUILD_NUMBER)"

if [[ -f "$RESOURCES_DIR/generate_icon.sh" && ! -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
  echo "Generating icon assets..."
  (cd "$RESOURCES_DIR" && ./generate_icon.sh) || echo "Icon generation skipped."
fi

echo "Running release tests..."
swift test

echo "Building release binary..."
swift build "${SWIFT_BUILD_ARGS[@]}"
BUILD_DIR="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)"

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

if [[ -f "$RESOURCES_DIR/AppIcon.icns" ]]; then
  cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
  ICON_FILE="AppIcon"
fi

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$EXECUTABLE_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$APP_IDENTIFIER</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.productivity</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>SUFeedURL</key>
  <string>https://raw.githubusercontent.com/alfonsobries/fluent-app/main/appcast.xml</string>
  <key>SUPublicEDKey</key>
  <string>MReBi9b1GiSQoQk+jrnd0K2KtJ55ptF/XeOw1jjh/Uo=</string>
</dict>
</plist>
EOF

if [[ -n "$ICON_FILE" ]]; then
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string $ICON_FILE" "$APP_BUNDLE/Contents/Info.plist"
fi

echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "Embedding Sparkle framework..."
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_FRAMEWORK="$(find "$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/../.." -path "*/Sparkle.framework" -type d -maxdepth 5 | head -1)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
  cp -R "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/"
  echo "  Embedded $SPARKLE_FRAMEWORK"
else
  echo "  WARNING: Sparkle.framework not found, auto-updates will not work"
fi

echo "Code signing with identity: $SIGNING_IDENTITY"
codesign --force --deep --options runtime --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Creating DMG..."
rm -f "$DMG_NAME"
rm -rf dmg_temp
mkdir -p dmg_temp
cp -R "$APP_BUNDLE" dmg_temp/
ln -s /Applications dmg_temp/Applications
hdiutil create -volname "$DISPLAY_NAME" -srcfolder dmg_temp -ov -format UDZO "$DMG_NAME"
rm -rf dmg_temp

if [[ "${NOTARIZE:-0}" == "1" ]]; then
  ./scripts/notarize.sh "$DMG_NAME"
fi

shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"

echo ""
echo "Artifacts:"
echo "  $APP_BUNDLE"
echo "  $DMG_NAME"
echo "  $DMG_NAME.sha256"
