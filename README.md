# BansheeRun

A running app that motivates runners by comparing their current pace against their "banshee" (best run) and plays audio cues when falling behind.

## Architecture

BansheeRun uses a **Shared Core** architecture where all pacing logic, GPS coordinate processing, and banshee comparisons are implemented in Rust, while platform-specific shells (Android/iOS) handle UI and system-level APIs (GPS, Audio, Notifications).

```
┌────────────────────────────────────────────────────────┐
│                    Mobile App                          │
├────────────────────────────────────────────────────────┤
│  ┌─────────────────┐     ┌─────────────────┐           │
│  │   Android UI    │     │     iOS UI      │           │
│  │   (Kotlin)      │     │    (Swift)      │           │
│  └────────┬────────┘     └────────┬────────┘           │
│           │                       │                    │
│  ┌────────▼────────┐     ┌────────▼────────┐           │
│  │ Android APIs    │     │   iOS APIs      │           │
│  │ - GPS Service   │     │ - CoreLocation  │           │
│  │ - AudioManager  │     │ - AVAudioSession│           │
│  │ - ForegroundSvc │     │ - Background    │           │
│  └────────┬────────┘     └────────┬────────┘           │
│           │                       │                    │
│           │       FFI Bridge      │                    │
│           │   (JNI / uniffi-rs)   │                    │
│           └───────────┬───────────┘                    │
│                       │                                │
│  ┌────────────────────▼────────────────────┐           │
│  │          Rust Core Library              │           │
│  │  ┌──────────────────────────────────┐   │           │
│  │  │        BansheeSession            │   │           │
│  │  │  - Pacing comparison logic       │   │           │
│  │  │  - Distance calculations         │   │           │
│  │  │  - Time interpolation            │   │           │
│  │  └──────────────────────────────────┘   │           │
│  │  ┌──────────────────────────────────┐   │           │
│  │  │         RunRecord                │   │           │
│  │  │  - Run persistence (JSON)        │   │           │
│  │  │  - Pace/speed calculations       │   │           │
│  │  └──────────────────────────────────┘   │           │
│  │  ┌──────────────────────────────────┐   │           │
│  │  │           Point                  │   │           │
│  │  │  - GPS coordinates               │   │           │
│  │  │  - Haversine distance            │   │           │
│  │  └──────────────────────────────────┘   │           │
│  └─────────────────────────────────────────┘           │
└────────────────────────────────────────────────────────┘
```

## Rust Core Library

The Rust core provides the "brain" of the application with the following components:

### Point

GPS coordinate representation with Haversine distance calculation.

```rust
use banshee_run::Point;

let nyc = Point::new(40.7128, -74.0060, 0);
let la = Point::new(34.0522, -118.2437, 0);
let distance = nyc.distance_to(&la); // ~3,935 km
```

### BansheeSession

Tracks the current run against a previous best run (the "banshee").

```rust
use banshee_run::{BansheeSession, Point};

// Load best run coordinates from storage
let best_run = vec![
    Point::new(40.7128, -74.0060, 0),
    Point::new(40.7135, -74.0055, 10000),
];
let session = BansheeSession::new(best_run);

// Check pacing in real-time
let current_pos = Point::new(40.7130, -74.0058, 15000);
if session.is_behind(&current_pos, 15000) {
    // Trigger scary music!
}
```

### RunRecord

Persistence for storing and loading run data as JSON.

```rust
use banshee_run::{RunRecord, Point};

let coords = vec![
    Point::new(40.7128, -74.0060, 0),
    Point::new(40.7135, -74.0055, 10000),
];
let record = RunRecord::new(
    "run-001".to_string(),
    "Morning 5K".to_string(),
    coords,
    1234567890
);

// Serialize to JSON for storage
let json = record.to_json().unwrap();

// Load from JSON
let loaded = RunRecord::from_json(&json).unwrap();
```

## Building

### Prerequisites

- Rust toolchain
- For Android: [cargo-ndk](https://github.com/nickelc/cargo-ndk) or NDK directly
- For iOS: Xcode and [cargo-xcode](https://gitlab.com/nickelc/cargo-xcode)

### Build Commands

```bash
# Build the library
cargo build --release

# Run tests
cargo test

# Build for Android (requires cargo-ndk)
cargo ndk -t arm64-v8a -t armeabi-v7a -o ./jniLibs build --release

# Build for iOS (requires cargo-apple)
cargo apple build --release
```

## Platform Integration

### Android Integration

The Android app uses a **Foreground Service** for reliable background operation:

1. **Location Updates**: Use `FusedLocationProviderClient` for GPS
2. **Audio Control**: Use `AudioManager` with `AUDIOFOCUS_GAIN_TRANSIENT` to duck/pause other apps
3. **JNI Bridge**: Use `jni-rs` or `uniffi-rs` for Rust-Kotlin communication

```kotlin
// Example Kotlin usage
external fun checkPacing(lat: Double, lon: Double, elapsedMillis: Long): Boolean

// In your Location Callback
val isBehind = checkPacing(location.latitude, location.longitude, elapsedMs)
if (isBehind) {
    triggerScaryMusic()
} else {
    stopScaryMusicAndResumeSpotify()
}
```

### iOS Integration

The iOS app uses **Background Modes** for location updates:

1. **CoreLocation**: For GPS updates in background
2. **AVAudioSession**: Use `.transient` category to interrupt other audio
3. **uniffi-rs**: Generates Swift bindings automatically

## Development Workflow

| Tool | Purpose |
| --- | --- |
| `cargo-ndk` | Compiles Rust for Android architectures |
| `uniffi-rs` | Generates bridge code for Kotlin and Swift |
| `cargo test` | Runs unit and integration tests |
| `cargo clippy` | Lints the codebase |
| `cargo fmt` | Formats the code |

