#!/bin/bash

# Generate macOS .icns icon from SVG
# Requires: rsvg-convert (librsvg) or ImageMagick

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SVG_FILE="$SCRIPT_DIR/AppIcon.svg"
ICONSET_DIR="$SCRIPT_DIR/AppIcon.iconset"
ICNS_FILE="$SCRIPT_DIR/AppIcon.icns"

echo "Creating iconset from SVG..."

# Create iconset directory
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Define sizes needed for macOS icons
# Format: name size
SIZES=(
    "icon_16x16 16"
    "icon_16x16@2x 32"
    "icon_32x32 32"
    "icon_32x32@2x 64"
    "icon_128x128 128"
    "icon_128x128@2x 256"
    "icon_256x256 256"
    "icon_256x256@2x 512"
    "icon_512x512 512"
    "icon_512x512@2x 1024"
)

# Try rsvg-convert first (better quality), then ImageMagick, then Quick Look
if command -v rsvg-convert &> /dev/null; then
    echo "Using rsvg-convert..."
    for entry in "${SIZES[@]}"; do
        name=$(echo $entry | cut -d' ' -f1)
        size=$(echo $entry | cut -d' ' -f2)
        echo "  Generating ${name}.png (${size}x${size})"
        rsvg-convert -w $size -h $size "$SVG_FILE" -o "$ICONSET_DIR/${name}.png"
    done
elif command -v convert &> /dev/null; then
    echo "Using ImageMagick..."
    for entry in "${SIZES[@]}"; do
        name=$(echo $entry | cut -d' ' -f1)
        size=$(echo $entry | cut -d' ' -f2)
        echo "  Generating ${name}.png (${size}x${size})"
        convert -background none -resize ${size}x${size} "$SVG_FILE" "$ICONSET_DIR/${name}.png"
    done
elif command -v qlmanage &> /dev/null && command -v sips &> /dev/null; then
    echo "Using Quick Look + sips..."
    TEMP_DIR="$(mktemp -d)"
    qlmanage -t -s 1024 -o "$TEMP_DIR" "$SVG_FILE" >/dev/null 2>&1
    BASE_PNG="$TEMP_DIR/$(basename "$SVG_FILE").png"
    for entry in "${SIZES[@]}"; do
        name=$(echo $entry | cut -d' ' -f1)
        size=$(echo $entry | cut -d' ' -f2)
        echo "  Generating ${name}.png (${size}x${size})"
        sips -z $size $size "$BASE_PNG" --out "$ICONSET_DIR/${name}.png" >/dev/null
    done
    rm -rf "$TEMP_DIR"
else
    echo "Error: No SVG rasterizer found."
    echo "Install with: brew install librsvg OR brew install imagemagick"
    exit 1
fi

# Convert iconset to icns (macOS only)
if command -v iconutil &> /dev/null; then
    echo "Converting to .icns..."
    iconutil -c icns "$ICONSET_DIR" -o "$ICNS_FILE"
    echo "Created: $ICNS_FILE"
    rm -rf "$ICONSET_DIR"
else
    echo "iconutil not found (requires macOS)."
    echo "Iconset created at: $ICONSET_DIR"
    echo "Run 'iconutil -c icns AppIcon.iconset -o AppIcon.icns' on macOS"
fi

echo "Done!"
