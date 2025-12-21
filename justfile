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
    cd flutter_app && flutter clean

# Install required Rust components
setup:
    rustup component add rustfmt clippy

# Setup all targets for cross-compilation
setup-all: setup setup-android

# === Android Builds (Rust library) ===

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

# === All Platforms ===

# Build for all platforms (requires all targets installed)
build-all: build build-android

# Full CI pipeline (all checks)
ci: check

# Full CI pipeline including cross-platform builds
ci-full: check build-android

# === Flutter App ===

# Get Flutter dependencies
flutter-pub-get:
    cd flutter_app && flutter pub get

# Analyze Flutter code
flutter-analyze:
    cd flutter_app && flutter analyze

# Build Flutter APK (debug)
flutter-build-debug: flutter-pub-get
    cd flutter_app && flutter build apk --debug

# Build Flutter APK (release)
flutter-build-release: flutter-pub-get
    cd flutter_app && flutter build apk --release

# Build Flutter app bundle (for Play Store)
flutter-build-appbundle: flutter-pub-get
    cd flutter_app && flutter build appbundle --release

# Run Flutter app
flutter-run:
    cd flutter_app && flutter run

# === Publish Pipeline ===

# Prepare release packages (APK)
prepare-packages: flutter-build-release
    mkdir -p packages
    cp flutter_app/build/app/outputs/flutter-apk/app-release.apk packages/bansheerun.apk

# Full publish preparation (everything except the release)
# Run this on PRs to validate the entire publish pipeline
publish-prepare: flutter-build-release prepare-packages

# === Release ===

# Generate a release version string
generate-version:
    @echo "v0.1.0-$(date +'%Y%m%d.%H%M%S')"

# List packages for upload (used by CI to verify packages exist)
list-packages:
    @ls -la packages/

# Create a GitHub release with APK
# Usage: just release v1.0.0
release version:
    gh release create "{{version}}" \
        --title "BansheeRun {{version}}" \
        --generate-notes \
        packages/bansheerun.apk
