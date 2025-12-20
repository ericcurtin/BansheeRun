//! Activity types and records for tracking runs, walks, cycles, and roller skating.

use crate::point::Point;
use serde::{Deserialize, Serialize};

/// Supported activity types.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ActivityType {
    Run,
    Walk,
    Cycle,
    RollerSkate,
}

impl ActivityType {
    /// Returns the standard PB distances for this activity type in meters.
    pub fn pb_distances(&self) -> &'static [f64] {
        match self {
            ActivityType::Run | ActivityType::Walk => &[
                1_000.0,  // 1K
                5_000.0,  // 5K
                10_000.0, // 10K
                21_097.5, // Half Marathon
                42_195.0, // Marathon
            ],
            ActivityType::Cycle => &[
                10_000.0,  // 10K
                25_000.0,  // 25K
                50_000.0,  // 50K
                100_000.0, // 100K
            ],
            ActivityType::RollerSkate => &[
                1_000.0,  // 1K
                5_000.0,  // 5K
                10_000.0, // 10K
                21_097.5, // Half Marathon
                42_195.0, // Marathon
            ],
        }
    }

    /// Human-readable name for each PB distance.
    pub fn distance_name(distance_m: f64) -> &'static str {
        match distance_m as u64 {
            1_000 => "1K",
            5_000 => "5K",
            10_000 => "10K",
            21_097 | 21_098 => "Half Marathon",
            42_195 => "Marathon",
            25_000 => "25K",
            50_000 => "50K",
            100_000 => "100K",
            _ => "Custom",
        }
    }

    /// Returns the activity type from an integer (for FFI).
    /// 0 = Run, 1 = Walk, 2 = Cycle, 3 = RollerSkate
    pub fn from_int(value: i32) -> Option<Self> {
        match value {
            0 => Some(ActivityType::Run),
            1 => Some(ActivityType::Walk),
            2 => Some(ActivityType::Cycle),
            3 => Some(ActivityType::RollerSkate),
            _ => None,
        }
    }

    /// Returns the integer representation of the activity type (for FFI).
    pub fn to_int(&self) -> i32 {
        match self {
            ActivityType::Run => 0,
            ActivityType::Walk => 1,
            ActivityType::Cycle => 2,
            ActivityType::RollerSkate => 3,
        }
    }
}

/// A complete record of an activity, suitable for persistence.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Activity {
    /// Unique identifier for the activity.
    pub id: String,
    /// Human-readable name for the activity (e.g., "Morning 5K Run").
    pub name: String,
    /// Type of activity (run, walk, or cycle).
    pub activity_type: ActivityType,
    /// GPS coordinates recorded during the activity.
    pub coordinates: Vec<Point>,
    /// Total distance in meters.
    pub total_distance_meters: f64,
    /// Total duration in milliseconds.
    pub duration_ms: u64,
    /// Timestamp when the activity was recorded (epoch milliseconds).
    pub recorded_at: u64,
}

impl Activity {
    /// Creates a new Activity from a list of GPS coordinates.
    pub fn new(
        id: String,
        name: String,
        activity_type: ActivityType,
        coordinates: Vec<Point>,
        recorded_at: u64,
    ) -> Self {
        let total_distance_meters = Self::calculate_total_distance(&coordinates);
        let duration_ms = Self::calculate_duration(&coordinates);

        Self {
            id,
            name,
            activity_type,
            coordinates,
            total_distance_meters,
            duration_ms,
            recorded_at,
        }
    }

    /// Calculates the duration in milliseconds from first to last point.
    fn calculate_duration(points: &[Point]) -> u64 {
        if points.len() < 2 {
            return 0;
        }
        let first_ts = points.first().map(|p| p.timestamp_ms).unwrap_or(0);
        let last_ts = points.last().map(|p| p.timestamp_ms).unwrap_or(0);
        last_ts.saturating_sub(first_ts)
    }

    /// Calculates the total distance covered in a sequence of points.
    fn calculate_total_distance(points: &[Point]) -> f64 {
        if points.len() < 2 {
            return 0.0;
        }
        points.windows(2).map(|w| w[0].distance_to(&w[1])).sum()
    }

    /// Calculates the average pace in minutes per kilometer.
    pub fn average_pace_min_per_km(&self) -> f64 {
        if self.total_distance_meters == 0.0 {
            return 0.0;
        }
        let duration_minutes = self.duration_ms as f64 / 60_000.0;
        let distance_km = self.total_distance_meters / 1000.0;
        duration_minutes / distance_km
    }

    /// Calculates the average speed in km/h.
    pub fn average_speed_kmh(&self) -> f64 {
        if self.duration_ms == 0 {
            return 0.0;
        }
        let duration_hours = self.duration_ms as f64 / 3_600_000.0;
        let distance_km = self.total_distance_meters / 1000.0;
        distance_km / duration_hours
    }

    /// Serializes the activity to JSON.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Serializes the activity to pretty-printed JSON.
    pub fn to_json_pretty(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    /// Deserializes an activity from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    /// Creates an ActivitySummary from this activity (without coordinates).
    pub fn to_summary(&self) -> ActivitySummary {
        ActivitySummary {
            id: self.id.clone(),
            name: self.name.clone(),
            activity_type: self.activity_type,
            total_distance_meters: self.total_distance_meters,
            duration_ms: self.duration_ms,
            recorded_at: self.recorded_at,
            pace_min_per_km: self.average_pace_min_per_km(),
        }
    }
}

/// Lightweight activity summary for list display (without coordinates).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ActivitySummary {
    /// Unique identifier for the activity.
    pub id: String,
    /// Human-readable name for the activity.
    pub name: String,
    /// Type of activity.
    pub activity_type: ActivityType,
    /// Total distance in meters.
    pub total_distance_meters: f64,
    /// Total duration in milliseconds.
    pub duration_ms: u64,
    /// Timestamp when the activity was recorded (epoch milliseconds).
    pub recorded_at: u64,
    /// Average pace in minutes per kilometer.
    pub pace_min_per_km: f64,
}

impl ActivitySummary {
    /// Serializes the summary to JSON.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Deserializes a summary from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}

/// Index of all activities for efficient list display.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct ActivityIndex {
    /// List of activity summaries.
    pub activities: Vec<ActivitySummary>,
}

impl ActivityIndex {
    /// Creates a new empty activity index.
    pub fn new() -> Self {
        Self {
            activities: Vec::new(),
        }
    }

    /// Adds an activity summary to the index.
    pub fn add(&mut self, summary: ActivitySummary) {
        self.activities.push(summary);
    }

    /// Removes an activity from the index by ID.
    pub fn remove(&mut self, id: &str) {
        self.activities.retain(|a| a.id != id);
    }

    /// Returns activities sorted by date (most recent first).
    pub fn sorted_by_date(&self) -> Vec<&ActivitySummary> {
        let mut sorted: Vec<_> = self.activities.iter().collect();
        sorted.sort_by(|a, b| b.recorded_at.cmp(&a.recorded_at));
        sorted
    }

    /// Returns activities filtered by type.
    pub fn filter_by_type(&self, activity_type: ActivityType) -> Vec<&ActivitySummary> {
        self.activities
            .iter()
            .filter(|a| a.activity_type == activity_type)
            .collect()
    }

    /// Serializes the index to JSON.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Deserializes an index from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_coords() -> Vec<Point> {
        vec![
            Point::new(40.7128, -74.0060, 0),
            Point::new(40.7132, -74.0057, 5000),
            Point::new(40.7136, -74.0054, 10000),
            Point::new(40.7140, -74.0051, 15000),
            Point::new(40.7144, -74.0048, 20000),
        ]
    }

    #[test]
    fn test_activity_type_pb_distances() {
        let run_distances = ActivityType::Run.pb_distances();
        assert_eq!(run_distances.len(), 5);
        assert_eq!(run_distances[0], 1_000.0);

        let cycle_distances = ActivityType::Cycle.pb_distances();
        assert_eq!(cycle_distances.len(), 4);
        assert_eq!(cycle_distances[0], 10_000.0);
    }

    #[test]
    fn test_activity_type_from_int() {
        assert_eq!(ActivityType::from_int(0), Some(ActivityType::Run));
        assert_eq!(ActivityType::from_int(1), Some(ActivityType::Walk));
        assert_eq!(ActivityType::from_int(2), Some(ActivityType::Cycle));
        assert_eq!(ActivityType::from_int(3), Some(ActivityType::RollerSkate));
        assert_eq!(ActivityType::from_int(4), None);
    }

    #[test]
    fn test_activity_creation() {
        let coords = create_test_coords();
        let activity = Activity::new(
            "test-001".to_string(),
            "Morning Run".to_string(),
            ActivityType::Run,
            coords,
            1234567890000,
        );

        assert_eq!(activity.id, "test-001");
        assert_eq!(activity.name, "Morning Run");
        assert_eq!(activity.activity_type, ActivityType::Run);
        assert!(activity.total_distance_meters > 0.0);
        assert_eq!(activity.duration_ms, 20000);
    }

    #[test]
    fn test_activity_json_serialization() {
        let coords = create_test_coords();
        let activity = Activity::new(
            "test-001".to_string(),
            "Morning Run".to_string(),
            ActivityType::Run,
            coords,
            1234567890000,
        );

        let json = activity.to_json().unwrap();
        assert!(json.contains("test-001"));
        assert!(json.contains("run"));

        let deserialized = Activity::from_json(&json).unwrap();
        assert_eq!(deserialized.id, activity.id);
        assert_eq!(deserialized.activity_type, activity.activity_type);
    }

    #[test]
    fn test_activity_summary() {
        let coords = create_test_coords();
        let activity = Activity::new(
            "test-001".to_string(),
            "Morning Run".to_string(),
            ActivityType::Run,
            coords,
            1234567890000,
        );

        let summary = activity.to_summary();
        assert_eq!(summary.id, activity.id);
        assert_eq!(summary.activity_type, activity.activity_type);
        assert!(summary.pace_min_per_km > 0.0);
    }

    #[test]
    fn test_activity_index() {
        let coords = create_test_coords();
        let activity1 = Activity::new(
            "run-001".to_string(),
            "Morning Run".to_string(),
            ActivityType::Run,
            coords.clone(),
            1000,
        );
        let activity2 = Activity::new(
            "walk-001".to_string(),
            "Evening Walk".to_string(),
            ActivityType::Walk,
            coords.clone(),
            2000,
        );

        let mut index = ActivityIndex::new();
        index.add(activity1.to_summary());
        index.add(activity2.to_summary());

        assert_eq!(index.activities.len(), 2);

        let sorted = index.sorted_by_date();
        assert_eq!(sorted[0].id, "walk-001"); // More recent first

        let runs = index.filter_by_type(ActivityType::Run);
        assert_eq!(runs.len(), 1);
        assert_eq!(runs[0].id, "run-001");
    }
}
