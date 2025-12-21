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
setup-all: setup setup-android

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

# === All Platforms ===

# Build for all platforms (requires all targets installed)
build-all: build build-android

# Full CI pipeline (all checks)
ci: check

# Full CI pipeline including cross-platform builds
ci-full: check build-android

# === Audio Assets ===

# Download scary audio files for Android
download-audio-android:
    mkdir -p android/app/src/main/res/raw
    curl -L -o android/app/src/main/res/raw/ambient_scary.mp3 "https://github.com/user-attachments/files/24278753/ambient_scary.mp3"
    curl -L -o android/app/src/main/res/raw/banshee_wail.mp3 "https://github.com/user-attachments/files/24278754/banshee_wail.mp3"
    curl -L -o android/app/src/main/res/raw/heartbeat.mp3 "https://github.com/user-attachments/files/24278755/heartbeat.mp3"
    curl -L -o android/app/src/main/res/raw/whispers.mp3 "https://github.com/user-attachments/files/24278756/whispers.mp3"

# Download all audio assets
download-audio: download-audio-android

# === Android APK Build ===

# Build Android APK (requires native libs in jniLibs and JDK)
build-apk: download-audio-android
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

# Prepare release packages (APK)
# Expects Android APK built
prepare-packages:
    mkdir -p packages
    cp android/app/build/outputs/apk/release/app-release.apk packages/bansheerun.apk

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
