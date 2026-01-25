#!/bin/bash

# GitHub Release Script for FluentApp
# Creates a new release with DMG artifact

set -e

# Check for version argument
if [ -z "$1" ]; then
    echo "Usage: ./scripts/release.sh <version>"
    echo "Example: ./scripts/release.sh 1.0.0"
    exit 1
fi

VERSION="$1"
TAG="v$VERSION"
DMG_NAME="FluentApp-${VERSION}.dmg"

echo "Creating release for FluentApp $VERSION..."

# Step 1: Build the app
echo ""
echo "Step 1: Building app..."
VERSION="$VERSION" ./build_dmg.sh

# Step 2: Verify DMG exists
if [ ! -f "$DMG_NAME" ]; then
    echo "Error: DMG file not found: $DMG_NAME"
    exit 1
fi

# Step 3: Create git tag
echo ""
echo "Step 2: Creating git tag $TAG..."
git tag -a "$TAG" -m "Release $VERSION"

# Step 4: Push tag
echo ""
echo "Step 3: Pushing tag to origin..."
git push origin "$TAG"

# Step 5: Create GitHub release (if gh CLI is installed)
if command -v gh &> /dev/null; then
    echo ""
    echo "Step 4: Creating GitHub release..."

    RELEASE_NOTES="## FluentApp $VERSION

### What's New
- See commit history for changes

### Installation
1. Download \`$DMG_NAME\`
2. Open the DMG file
3. Drag FluentApp to your Applications folder
4. Open FluentApp from Applications
5. Grant Accessibility permissions when prompted
6. Add your OpenAI API key in settings

### Requirements
- macOS 13.0 (Ventura) or later
- OpenAI API key

### Checksums
\`\`\`
$(cat "$DMG_NAME.sha256" 2>/dev/null || echo "SHA256 not available")
\`\`\`
"

    gh release create "$TAG" "$DMG_NAME" "$DMG_NAME.sha256" \
        --title "FluentApp $VERSION" \
        --notes "$RELEASE_NOTES"

    echo ""
    echo "Release created successfully!"
    echo "View at: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name')/releases/tag/$TAG"
else
    echo ""
    echo "GitHub CLI (gh) not installed. To create the release manually:"
    echo "  1. Go to your GitHub repository"
    echo "  2. Click 'Releases' -> 'Create a new release'"
    echo "  3. Choose tag: $TAG"
    echo "  4. Upload: $DMG_NAME"
    echo "  5. Publish the release"
fi

echo ""
echo "Done!"
