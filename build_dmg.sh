#!/bin/bash

# FluentApp Build Script
# Builds the app and creates a distributable DMG

set -e

APP_NAME="FluentApp"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
RESOURCES_DIR="Resources"

echo "========================================"
echo "  Building $APP_NAME v$VERSION"
echo "========================================"

# Step 1: Generate icon if needed
if [ -f "$RESOURCES_DIR/generate_icon.sh" ] && [ ! -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    echo ""
    echo "Generating app icon..."
    cd "$RESOURCES_DIR"
    ./generate_icon.sh || echo "Warning: Icon generation failed. Using default icon."
    cd ..
fi

# Step 2: Build the app
echo ""
echo "Compiling Swift code (release mode)..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "Build failed."
    exit 1
fi

# Step 3: Create App Bundle
echo ""
echo "Creating App Bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"

# Copy icon if exists
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
    ICON_FILE="AppIcon"
else
    ICON_FILE=""
fi

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.alfonsobries.FluentApp</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>Fluent</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024 Alfonso Bribiesca. MIT License.</string>
EOF

# Add icon reference if we have one
if [ -n "$ICON_FILE" ]; then
cat >> "$APP_BUNDLE/Contents/Info.plist" <<EOF
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
EOF
fi

cat >> "$APP_BUNDLE/Contents/Info.plist" <<EOF
</dict>
</plist>
EOF

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

echo "App Bundle created: $APP_BUNDLE"

# Step 4: Code Sign the app (ad-hoc signing)
echo ""
echo "Code signing the app (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"
echo "Code signing complete."

# Step 5: Create DMG
echo ""
echo "Creating DMG installer..."
rm -f "$DMG_NAME"

# Create a temporary folder for DMG contents
DMG_TEMP="dmg_temp"
rm -rf "$DMG_TEMP"
mkdir -p "$DMG_TEMP"
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create a symbolic link to Applications folder
ln -s /Applications "$DMG_TEMP/Applications"

# Create the DMG
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_TEMP" -ov -format UDZO "$DMG_NAME"

# Cleanup
rm -rf "$DMG_TEMP"

# Step 6: Generate checksums
echo ""
echo "Generating checksums..."
if command -v shasum &> /dev/null; then
    shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
    echo "SHA256: $(cat "$DMG_NAME.sha256")"
fi

echo ""
echo "========================================"
echo "  Build Complete!"
echo "========================================"
echo ""
echo "  App Bundle: $APP_BUNDLE"
echo "  DMG File:   $DMG_NAME"
echo "  Version:    $VERSION (build $BUILD_NUMBER)"
echo ""
echo "  To install:"
echo "    1. Open $DMG_NAME"
echo "    2. Drag $APP_NAME to Applications"
echo "    3. Run from Applications"
echo "    4. Grant Accessibility permissions when prompted"
echo ""
