#!/bin/bash
# Build script for BansheeRun macOS app
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$SCRIPT_DIR/build"
APP_NAME="BansheeRun"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

# Determine architecture
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
    RUST_TARGET="aarch64-apple-darwin"
else
    RUST_TARGET="x86_64-apple-darwin"
fi

RUST_LIB_DIR="$PROJECT_ROOT/target/$RUST_TARGET/release"

echo "Building BansheeRun macOS app..."
echo "Architecture: $ARCH"
echo "Rust target: $RUST_TARGET"

# Build Rust library if needed
if [ ! -f "$RUST_LIB_DIR/libbanshee_run.a" ]; then
    echo "Building Rust library..."
    cd "$PROJECT_ROOT"
    cargo build --release --target "$RUST_TARGET"
fi

# Create build directory
mkdir -p "$BUILD_DIR"

# Create app bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy Info.plist
cp "$SCRIPT_DIR/BansheeRun/Info.plist" "$APP_BUNDLE/Contents/"

# Update Info.plist with actual values
/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.bansheerun.BansheeRun" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Set :CFBundlePackageType APPL" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

# Create PkgInfo
echo "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

# Copy audio resources
echo "Copying audio resources..."
if [ -d "$SCRIPT_DIR/BansheeRun/Resources" ]; then
    cp "$SCRIPT_DIR/BansheeRun/Resources/"*.mp3 "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Compile Swift sources
echo "Compiling Swift sources..."
SWIFT_SOURCES=(
    "$SCRIPT_DIR/BansheeRun/BansheeRunApp.swift"
    "$SCRIPT_DIR/BansheeRun/ContentView.swift"
    "$SCRIPT_DIR/BansheeRun/BansheeLib.swift"
    "$SCRIPT_DIR/BansheeRun/LocationManager.swift"
    "$SCRIPT_DIR/BansheeRun/ActivityRepository.swift"
    "$SCRIPT_DIR/BansheeRun/ActivityListView.swift"
    "$SCRIPT_DIR/BansheeRun/BansheeAudioManager.swift"
)

swiftc \
    -O \
    -whole-module-optimization \
    -target "${ARCH}-apple-macosx13.0" \
    -sdk "$(xcrun --show-sdk-path)" \
    -import-objc-header "$SCRIPT_DIR/BansheeRun/BansheeRun-Bridging-Header.h" \
    -L "$RUST_LIB_DIR" \
    -lbanshee_run \
    -framework CoreLocation \
    -framework SwiftUI \
    -framework AppKit \
    -framework AVFoundation \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "${SWIFT_SOURCES[@]}"

# Sign the app (ad-hoc for local development)
echo "Signing app..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "Build complete: $APP_BUNDLE"
echo ""
echo "To run the app:"
echo "  open $APP_BUNDLE"
echo ""
echo "To install to Applications:"
echo "  cp -r $APP_BUNDLE /Applications/"
