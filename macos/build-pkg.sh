#!/bin/bash
# Build script for BansheeRun macOS .pkg installer
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/BansheeRun.app"
PKG_OUTPUT="$BUILD_DIR/BansheeRun.pkg"
IDENTIFIER="com.bansheerun.BansheeRun"
VERSION="1.0.0"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

echo "Building BansheeRun macOS .pkg installer..."

# Build the app first if it doesn't exist
if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found, building..."
    "$SCRIPT_DIR/build.sh"
fi

# Verify app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    exit 1
fi

# Create a temporary directory for the package root
PKG_ROOT=$(mktemp -d)
trap "rm -rf $PKG_ROOT" EXIT

# Create Applications directory structure in package root
mkdir -p "$PKG_ROOT/Applications"

# Copy app bundle to package root
cp -r "$APP_BUNDLE" "$PKG_ROOT/Applications/"

# Build the installer package
echo "Creating .pkg installer..."
pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --install-location "/" \
    "$PKG_OUTPUT"

echo ""
echo "Package created: $PKG_OUTPUT"
echo ""
echo "To install:"
echo "  sudo installer -pkg $PKG_OUTPUT -target /"
echo "Or double-click the .pkg file in Finder"
