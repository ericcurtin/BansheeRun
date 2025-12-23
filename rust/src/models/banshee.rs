use serde::{Deserialize, Serialize};

/// Type of banshee/pacer
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum BansheeType {
    /// Banshee based on a previous recorded run
    RecordedRun { run_id: String },
    /// AI-generated pacer with target pace
    AiPacer {
        /// Target pace in seconds per kilometer
        target_pace_sec_per_km: f64,
    },
}

/// A banshee runner to race against
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Banshee {
    /// Type of banshee (recorded run or AI pacer)
    pub banshee_type: BansheeType,
    /// Display name for the banshee
    pub name: String,
}

impl Banshee {
    /// Create a banshee from a recorded run
    pub fn from_run(run_id: String, name: String) -> Self {
        Self {
            banshee_type: BansheeType::RecordedRun { run_id },
            name,
        }
    }

    /// Create an AI pacer banshee with target pace
    /// pace_sec_per_km: target pace in seconds per kilometer (e.g., 300 = 5:00/km)
    pub fn ai_pacer(target_pace_sec_per_km: f64, name: String) -> Self {
        Self {
            banshee_type: BansheeType::AiPacer {
                target_pace_sec_per_km,
            },
            name,
        }
    }

    /// Create an AI pacer from minutes per kilometer
    pub fn ai_pacer_from_min_per_km(minutes: f64, name: String) -> Self {
        Self::ai_pacer(minutes * 60.0, name)
    }

    /// Get target pace in seconds per km (for AI pacers)
    pub fn target_pace(&self) -> Option<f64> {
        match &self.banshee_type {
            BansheeType::AiPacer {
                target_pace_sec_per_km,
            } => Some(*target_pace_sec_per_km),
            BansheeType::RecordedRun { .. } => None,
        }
    }

    /// Get run ID (for recorded run banshees)
    pub fn run_id(&self) -> Option<&str> {
        match &self.banshee_type {
            BansheeType::RecordedRun { run_id } => Some(run_id),
            BansheeType::AiPacer { .. } => None,
        }
    }

    /// Check if this is an AI pacer
    pub fn is_ai_pacer(&self) -> bool {
        matches!(self.banshee_type, BansheeType::AiPacer { .. })
    }
}

/// Represents the banshee's current state during a run
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BansheeState {
    /// Current position of the banshee
    pub lat: f64,
    pub lon: f64,
    /// Distance covered by the banshee in meters
    pub distance_meters: f64,
    /// Time offset from the runner in milliseconds (positive = banshee ahead)
    pub time_delta_ms: i64,
    /// Distance offset from the runner in meters (positive = banshee ahead)
    pub distance_delta_meters: f64,
}

impl BansheeState {
    pub fn new(lat: f64, lon: f64, distance_meters: f64) -> Self {
        Self {
            lat,
            lon,
            distance_meters,
            time_delta_ms: 0,
            distance_delta_meters: 0.0,
        }
    }

    /// Returns true if the banshee is ahead of the runner
    pub fn is_ahead(&self) -> bool {
        self.distance_delta_meters > 0.0
    }

    /// Format the delta for display
    pub fn delta_display(&self) -> String {
        let abs_distance = self.distance_delta_meters.abs();
        let direction = if self.is_ahead() { "behind" } else { "ahead" };

        if abs_distance < 1000.0 {
            format!("{:.0}m {}", abs_distance, direction)
        } else {
            format!("{:.2}km {}", abs_distance / 1000.0, direction)
        }
    }
}
