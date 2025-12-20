# Justfile for BansheeRun
# Run `just --list` to see all available recipes

# Default recipe runs all checks (same as CI)
default: check

# Run all CI checks (build, test, clippy, fmt)
check: build test clippy fmt-check

# Build in release mode
build:
    cargo build --release

# Build in debug mode
build-debug:
    cargo build

# Run tests
test:
    cargo test

# Run clippy with warnings as errors
clippy:
    cargo clippy -- -D warnings

# Check code formatting
fmt-check:
    cargo fmt -- --check

# Format code
fmt:
    cargo fmt

# Clean build artifacts
clean:
    cargo clean

# Install required Rust components
setup:
    rustup component add rustfmt clippy

# Setup all targets for cross-compilation
setup-all: setup setup-android setup-ios setup-macos

# === Android Builds ===

# Install cargo-ndk for Android builds
install-ndk:
    cargo install cargo-ndk

# Install Android targets
setup-android: install-ndk
    rustup target add aarch64-linux-android armv7-linux-androideabi

# Build for Android arm64-v8a
build-android-arm64:
    cargo ndk -t arm64-v8a build --release

# Build for Android armeabi-v7a
build-android-arm32:
    cargo ndk -t armeabi-v7a build --release

# Build for all Android targets
build-android: build-android-arm64 build-android-arm32

# === iOS Builds ===

# Install iOS targets
setup-ios:
    rustup target add aarch64-apple-ios x86_64-apple-ios aarch64-apple-ios-sim

# Build for iOS device (arm64)
build-ios-device:
    cargo build --release --target aarch64-apple-ios

# Build for iOS simulator (x86_64)
build-ios-sim-x86:
    cargo build --release --target x86_64-apple-ios

# Build for iOS simulator (arm64)
build-ios-sim-arm64:
    cargo build --release --target aarch64-apple-ios-sim

# Build for all iOS targets
build-ios: build-ios-device build-ios-sim-x86 build-ios-sim-arm64

# === macOS Builds ===

# Install macOS target
setup-macos:
    rustup target add aarch64-apple-darwin

# Build for macOS Apple Silicon (arm64)
build-macos:
    cargo build --release --target aarch64-apple-darwin

# === All Platforms ===

# Build for all platforms (requires all targets installed)
build-all: build build-android build-ios build-macos

# Full CI pipeline (all checks)
ci: check

# Full CI pipeline including cross-platform builds
ci-full: check build-android build-ios build-macos

# === Android APK Build ===

# Build Android APK (requires native libs in jniLibs and JDK)
build-apk:
    cd android && gradle assembleRelease --no-daemon

# === Publish Pipeline ===

# Create Android debug keystore if it doesn't exist
create-android-keystore:
    mkdir -p ~/.android
    if [ ! -f ~/.android/debug.keystore ]; then \
        keytool -genkey -v -keystore ~/.android/debug.keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"; \
    fi

# Copy native libraries from artifacts to Android jniLibs
# Expects artifacts in ./artifacts/ directory
copy-android-libs:
    mkdir -p android/app/src/main/jniLibs/arm64-v8a
    mkdir -p android/app/src/main/jniLibs/armeabi-v7a
    if [ -d "artifacts/android-arm64-v8a" ]; then \
        cp artifacts/android-arm64-v8a/*.so android/app/src/main/jniLibs/arm64-v8a/; \
    fi
    if [ -d "artifacts/android-armeabi-v7a" ]; then \
        cp artifacts/android-armeabi-v7a/*.so android/app/src/main/jniLibs/armeabi-v7a/; \
    fi

# Prepare release packages (APK + iOS zip + macOS pkg)
# Expects Android APK built and iOS/macOS artifacts in ./artifacts/
prepare-packages:
    mkdir -p packages
    cp android/app/build/outputs/apk/release/app-release.apk packages/bansheerun.apk
    mkdir -p packages/ios
    if [ -d "artifacts/ios-arm64" ]; then \
        cp artifacts/ios-arm64/*.a packages/ios/; \
    fi
    if [ -d "artifacts/ios-x86_64-simulator" ]; then \
        cp artifacts/ios-x86_64-simulator/*.a packages/ios/; \
    fi
    if [ -d "artifacts/ios-arm64-simulator" ]; then \
        cp artifacts/ios-arm64-simulator/*.a packages/ios/; \
    fi
    cd packages && zip -r bansheerun-ios.zip ios/
    mkdir -p packages/macos
    if [ -d "artifacts/macos-arm64" ]; then \
        cp artifacts/macos-arm64/*.a packages/macos/; \
        cp artifacts/macos-arm64/*.dylib packages/macos/; \
    fi
    cd packages && zip -r bansheerun-macos.zip macos/

# Full publish preparation (everything except the release)
# Run this on PRs to validate the entire publish pipeline
publish-prepare: copy-android-libs create-android-keystore build-apk prepare-packages

# === Release ===

# Generate a release version string
generate-version:
    @echo "v0.1.0-$(date +'%Y%m%d.%H%M%S')"

# Show structure of artifacts directory (for debugging)
show-artifacts:
    ls -R artifacts

# Create a GitHub release with APK, iOS, and macOS packages
# Usage: just release v1.0.0
release version:
    gh release create "{{version}}" \
        --title "BansheeRun {{version}}" \
        --generate-notes \
        packages/bansheerun.apk \
        packages/bansheerun-ios.zip \
        packages/bansheerun-macos.zip
