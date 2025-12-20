//! BansheeRun Core Library
//!
//! This library provides the core pacing logic and ghost comparison functionality
//! for the BansheeRun running app. It is designed to be cross-platform, compiled
//! as a shared library for Android and a static library for iOS.
//!
//! # Architecture
//!
//! The library follows a "Shared Core" architecture where all pacing logic,
//! GPS coordinate processing, and ghost comparisons are handled in Rust,
//! while platform-specific shells (Android/iOS) handle UI and system APIs.

pub mod ghost_session;
pub mod point;
pub mod run_record;

pub use ghost_session::GhostSession;
pub use point::Point;
pub use run_record::RunRecord;
