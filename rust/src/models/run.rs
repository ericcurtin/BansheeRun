use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use super::GpsPoint;

/// A recorded run with GPS track and statistics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Run {
    /// Unique identifier for this run
    pub id: String,
    /// User-provided name for this run (optional)
    pub name: Option<String>,
    /// When the run started
    pub start_time: DateTime<Utc>,
    /// When the run ended (None if still in progress)
    pub end_time: Option<DateTime<Utc>>,
    /// All GPS points recorded during the run
    pub points: Vec<GpsPoint>,
    /// Total distance in meters
    pub distance_meters: f64,
    /// Duration in milliseconds
    pub duration_ms: i64,
    /// Average pace in seconds per kilometer
    pub avg_pace_sec_per_km: Option<f64>,
}

impl Run {
    /// Create a new run starting now
    pub fn new() -> Self {
        Self {
            id: Uuid::new_v4().to_string(),
            name: None,
            start_time: Utc::now(),
            end_time: None,
            points: Vec::new(),
            distance_meters: 0.0,
            duration_ms: 0,
            avg_pace_sec_per_km: None,
        }
    }

    /// Create a run with a specific ID (for loading from database)
    pub fn with_id(id: String) -> Self {
        Self {
            id,
            name: None,
            start_time: Utc::now(),
            end_time: None,
            points: Vec::new(),
            distance_meters: 0.0,
            duration_ms: 0,
            avg_pace_sec_per_km: None,
        }
    }

    /// Add a GPS point to this run
    pub fn add_point(&mut self, point: GpsPoint) {
        self.points.push(point);
    }

    /// Finish the run
    pub fn finish(&mut self) {
        self.end_time = Some(Utc::now());
        if let Some(end) = self.end_time {
            self.duration_ms = (end - self.start_time).num_milliseconds();
        }
    }

    /// Check if run is in progress
    pub fn is_active(&self) -> bool {
        self.end_time.is_none()
    }

    /// Get duration as formatted string (HH:MM:SS)
    pub fn duration_formatted(&self) -> String {
        let total_secs = self.duration_ms / 1000;
        let hours = total_secs / 3600;
        let minutes = (total_secs % 3600) / 60;
        let seconds = total_secs % 60;

        if hours > 0 {
            format!("{}:{:02}:{:02}", hours, minutes, seconds)
        } else {
            format!("{}:{:02}", minutes, seconds)
        }
    }

    /// Get distance in kilometers
    pub fn distance_km(&self) -> f64 {
        self.distance_meters / 1000.0
    }

    /// Get distance in miles
    pub fn distance_miles(&self) -> f64 {
        self.distance_meters / 1609.344
    }
}

impl Default for Run {
    fn default() -> Self {
        Self::new()
    }
}

/// Summary information for a run (used in lists)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunSummary {
    pub id: String,
    pub name: Option<String>,
    pub start_time: DateTime<Utc>,
    pub distance_meters: f64,
    pub duration_ms: i64,
    pub avg_pace_sec_per_km: Option<f64>,
}

impl From<&Run> for RunSummary {
    fn from(run: &Run) -> Self {
        Self {
            id: run.id.clone(),
            name: run.name.clone(),
            start_time: run.start_time,
            distance_meters: run.distance_meters,
            duration_ms: run.duration_ms,
            avg_pace_sec_per_km: run.avg_pace_sec_per_km,
        }
    }
}
