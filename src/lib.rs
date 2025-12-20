//! BansheeRun Core Library
//!
//! This library provides the core pacing logic and banshee comparison functionality
//! for the BansheeRun running app. It is designed to be cross-platform, compiled
//! as a shared library for Android and a static library for iOS.
//!
//! # Architecture
//!
//! The library follows a "Shared Core" architecture where all pacing logic,
//! GPS coordinate processing, and banshee comparisons are handled in Rust,
//! while platform-specific shells (Android/iOS) handle UI and system APIs.

pub mod activity;
pub mod banshee_session;
pub mod pb_calculator;
pub mod personal_best;
pub mod point;
pub mod run_record;

#[cfg(target_os = "android")]
mod android;

#[cfg(any(target_os = "macos", target_os = "ios"))]
mod macos;

pub use activity::{Activity, ActivityIndex, ActivitySummary, ActivityType};
pub use banshee_session::BansheeSession;
pub use pb_calculator::{calculate_speed_kmh, format_pace, PBCalculator};
pub use personal_best::{PersonalBest, PersonalBests};
pub use point::Point;
pub use run_record::RunRecord;
