# BansheeRun Justfile
# Run `just --list` to see all available recipes

# Use PowerShell on Windows to avoid WSL/bash issues
set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# Default recipe - show help
default:
    @just --list

# ============================================================================
# Setup
# ============================================================================

# Install all dependencies
setup: setup-rust setup-flutter

# Install Rust dependencies
setup-rust:
    cargo install 'flutter_rust_bridge_codegen@^2.0.0'
    cd rust && cargo fetch

# Install Flutter dependencies
setup-flutter:
    flutter pub get

# ============================================================================
# Code Generation
# ============================================================================

# Generate flutter_rust_bridge bindings
generate:
    flutter_rust_bridge_codegen generate

# Generate bindings in watch mode
generate-watch:
    flutter_rust_bridge_codegen generate --watch

# ============================================================================
# Build
# ============================================================================

# Build Rust library (check only)
build-rust:
    cd rust && cargo build --release

# Check Rust compilation
check-rust:
    cd rust && cargo check

# Build Flutter app for current platform
build:
    flutter build

# Build Android APK
build-android:
    flutter build apk --release

# Build Android App Bundle
build-android-bundle:
    flutter build appbundle --release

# Build iOS
build-ios:
    flutter build ios --release --no-codesign

# Build Linux
build-linux:
    flutter build linux --release

# Build macOS
build-macos:
    flutter build macos --release

# Build Windows
build-windows:
    flutter build windows --release

# ============================================================================
# Packaging
# ============================================================================

# Package Linux as .deb
package-linux-deb: build-linux
    #!/usr/bin/env bash
    set -euo pipefail

    APP_NAME="banshee-run"
    VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        DEB_ARCH="amd64"
    elif [ "$ARCH" = "aarch64" ]; then
        DEB_ARCH="arm64"
    else
        DEB_ARCH="$ARCH"
    fi

    DEB_DIR="build/${APP_NAME}_${VERSION}_${DEB_ARCH}"

    # Clean and create directory structure
    rm -rf "$DEB_DIR"
    mkdir -p "$DEB_DIR/DEBIAN"
    mkdir -p "$DEB_DIR/usr/bin"
    mkdir -p "$DEB_DIR/usr/lib/${APP_NAME}"
    mkdir -p "$DEB_DIR/usr/share/applications"
    mkdir -p "$DEB_DIR/usr/share/icons/hicolor/256x256/apps"

    # Copy built files
    cp -r build/linux/x64/release/bundle/* "$DEB_DIR/usr/lib/${APP_NAME}/"

    # Create launcher script
    cat > "$DEB_DIR/usr/bin/${APP_NAME}" << 'LAUNCHER'
    #!/bin/bash
    cd /usr/lib/banshee-run
    exec ./banshee_run_app "$@"
    LAUNCHER
    chmod +x "$DEB_DIR/usr/bin/${APP_NAME}"

    # Create desktop entry
    cat > "$DEB_DIR/usr/share/applications/${APP_NAME}.desktop" << DESKTOP
    [Desktop Entry]
    Name=BansheeRun
    Comment=Virtual Pacer and Banshee Runner
    Exec=${APP_NAME}
    Icon=${APP_NAME}
    Terminal=false
    Type=Application
    Categories=Sports;Utility;
    DESKTOP

    # Create control file
    cat > "$DEB_DIR/DEBIAN/control" << CONTROL
    Package: ${APP_NAME}
    Version: ${VERSION}
    Section: misc
    Priority: optional
    Architecture: ${DEB_ARCH}
    Depends: libgtk-3-0, libblkid1, liblzma5
    Maintainer: BansheeRun Team
    Description: Virtual Pacer and Banshee Runner
     Race against your previous performances or AI-generated
     pace targets with real-time GPS tracking.
    CONTROL

    # Build the .deb
    dpkg-deb --build "$DEB_DIR"
    echo "Created: ${DEB_DIR}.deb"

# Package macOS as .dmg
package-macos-dmg: build-macos
    #!/usr/bin/env bash
    set -euo pipefail

    APP_NAME="BansheeRun"
    VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
    DMG_NAME="${APP_NAME}_${VERSION}_macos"

    # Clean previous builds
    rm -rf "build/${DMG_NAME}.dmg"
    rm -rf "build/dmg_temp"

    # Create temp directory for DMG contents
    mkdir -p "build/dmg_temp"

    # Copy app bundle
    cp -r "build/macos/Build/Products/Release/${APP_NAME}.app" "build/dmg_temp/"

    # Create symlink to Applications
    ln -s /Applications "build/dmg_temp/Applications"

    # Create DMG
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "build/dmg_temp" \
        -ov -format UDZO \
        "build/${DMG_NAME}.dmg"

    # Clean up
    rm -rf "build/dmg_temp"

    echo "Created: build/${DMG_NAME}.dmg"

# Package Windows as .exe installer (requires Inno Setup)
package-windows-exe: build-windows
    #!/usr/bin/env bash
    set -euo pipefail

    APP_NAME="BansheeRun"
    VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)

    # Create Inno Setup script
    cat > "build/installer.iss" << ISS
    [Setup]
    AppName=${APP_NAME}
    AppVersion=${VERSION}
    AppPublisher=BansheeRun Team
    DefaultDirName={autopf}\\${APP_NAME}
    DefaultGroupName=${APP_NAME}
    OutputDir=.
    OutputBaseFilename=${APP_NAME}_${VERSION}_windows_setup
    Compression=lzma
    SolidCompression=yes
    ArchitecturesInstallIn64BitMode=x64

    [Files]
    Source: "windows\\x64\\runner\\Release\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

    [Icons]
    Name: "{group}\\${APP_NAME}"; Filename: "{app}\\banshee_run_app.exe"
    Name: "{autodesktop}\\${APP_NAME}"; Filename: "{app}\\banshee_run_app.exe"

    [Run]
    Filename: "{app}\\banshee_run_app.exe"; Description: "Launch ${APP_NAME}"; Flags: postinstall nowait
    ISS

    # Run Inno Setup (Windows only, or via Wine)
    if command -v iscc &> /dev/null; then
        iscc "build/installer.iss"
    elif command -v wine &> /dev/null && [ -f "$HOME/.wine/drive_c/Program Files (x86)/Inno Setup 6/ISCC.exe" ]; then
        wine "$HOME/.wine/drive_c/Program Files (x86)/Inno Setup 6/ISCC.exe" "build/installer.iss"
    else
        echo "Warning: Inno Setup not found. Installer script created at build/installer.iss"
        echo "Run with Inno Setup to create the .exe installer"
    fi

# Package Android APK (just copies the built APK)
package-android-apk: build-android
    #!/usr/bin/env bash
    set -euo pipefail

    VERSION=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1)
    cp build/app/outputs/flutter-apk/app-release.apk "build/BansheeRun_${VERSION}_android.apk"
    echo "Created: build/BansheeRun_${VERSION}_android.apk"

# ============================================================================
# Testing
# ============================================================================

# Run all tests
test: test-rust test-flutter

# Run Rust tests
test-rust:
    cd rust && cargo test

# Run Flutter tests
test-flutter:
    flutter test

# Run integration tests
test-integration:
    flutter test integration_test

# ============================================================================
# Linting & Formatting
# ============================================================================

# Run all lints
lint: lint-rust lint-flutter

# Lint Rust code
lint-rust:
    cd rust && cargo clippy -- -D warnings

# Lint Flutter code
lint-flutter:
    flutter analyze

# Format all code
format: format-rust format-flutter

# Format Rust code
format-rust:
    cd rust && cargo fmt

# Format Flutter code
format-flutter:
    dart format lib test integration_test

# Check formatting without modifying
format-check: format-check-rust format-check-flutter

# Check Rust formatting
format-check-rust:
    cd rust && cargo fmt --check

# Check Flutter formatting
format-check-flutter:
    dart format --set-exit-if-changed --output=none lib test integration_test

# ============================================================================
# CI Recipes
# ============================================================================

# CI: Full check (used in PR checks)
ci-check: setup-flutter generate check-rust lint test

# CI: Build all platforms (for release)
ci-build-all: setup-flutter generate build-android build-linux build-macos build-windows

# ============================================================================
# Development
# ============================================================================

# Run the app in debug mode
run:
    flutter run

# Run the app on a specific device
run-device device:
    flutter run -d {{device}}

# Clean all build artifacts
clean:
    flutter clean
    cd rust && cargo clean
    rm -rf build/

# Get app version from pubspec.yaml
version:
    @grep 'version:' pubspec.yaml | head -1 | awk '{print $2}' | cut -d'+' -f1

# Bump version (patch)
bump-patch:
    #!/usr/bin/env bash
    set -euo pipefail
    CURRENT=$(grep 'version:' pubspec.yaml | head -1 | awk '{print $2}')
    VERSION=$(echo $CURRENT | cut -d'+' -f1)
    BUILD=$(echo $CURRENT | cut -d'+' -f2)
    MAJOR=$(echo $VERSION | cut -d'.' -f1)
    MINOR=$(echo $VERSION | cut -d'.' -f2)
    PATCH=$(echo $VERSION | cut -d'.' -f3)
    NEW_PATCH=$((PATCH + 1))
    NEW_BUILD=$((BUILD + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}+${NEW_BUILD}"
    sed -i.bak "s/version: .*/version: ${NEW_VERSION}/" pubspec.yaml
    rm -f pubspec.yaml.bak
    echo "Bumped version to ${NEW_VERSION}"
