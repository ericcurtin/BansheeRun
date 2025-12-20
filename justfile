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

# === All Platforms ===

# Build for all platforms (requires all targets installed)
build-all: build build-android build-ios

# Full CI pipeline (all checks)
ci: check

# Full CI pipeline including cross-platform builds
ci-full: check build-android build-ios

# === Android APK Build ===

# Build Android APK (requires native libs in jniLibs and JDK)
build-apk:
    cd android && ./gradlew assembleRelease --no-daemon

# === Release ===

# Create a GitHub release with APK and iOS packages
# Usage: just release v1.0.0
release version:
    gh release create "{{version}}" \
        --title "BansheeRun {{version}}" \
        --generate-notes \
        packages/bansheerun.apk \
        packages/bansheerun-ios.zip
