//! Run Record - Persistence for storing and loading run data.

use crate::point::Point;
use serde::{Deserialize, Serialize};

/// A complete record of a run, suitable for persistence.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RunRecord {
    /// Unique identifier for the run.
    pub id: String,
    /// Human-readable name for the run (e.g., "Morning 5K").
    pub name: String,
    /// GPS coordinates recorded during the run.
    pub coordinates: Vec<Point>,
    /// Total distance in meters.
    pub total_distance_meters: f64,
    /// Total duration in milliseconds.
    pub duration_ms: u64,
    /// Timestamp when the run was recorded (epoch milliseconds).
    pub recorded_at: u64,
}

impl RunRecord {
    /// Creates a new RunRecord from a list of GPS coordinates.
    ///
    /// # Arguments
    ///
    /// * `id` - Unique identifier for the run
    /// * `name` - Human-readable name for the run
    /// * `coordinates` - GPS coordinates recorded during the run
    /// * `recorded_at` - Timestamp when the run was recorded (epoch milliseconds)
    ///
    /// # Example
    ///
    /// ```
    /// use banshee_run::{RunRecord, Point};
    ///
    /// let coords = vec![
    ///     Point::new(40.7128, -74.0060, 0),
    ///     Point::new(40.7135, -74.0055, 10000),
    /// ];
    /// let record = RunRecord::new("run-001".to_string(), "Morning Run".to_string(), coords, 1234567890);
    /// ```
    pub fn new(id: String, name: String, coordinates: Vec<Point>, recorded_at: u64) -> Self {
        let total_distance_meters = Self::calculate_total_distance(&coordinates);
        let duration_ms = coordinates.last().map(|p| p.timestamp_ms).unwrap_or(0);

        Self {
            id,
            name,
            coordinates,
            total_distance_meters,
            duration_ms,
            recorded_at,
        }
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

    /// Serializes the run record to JSON.
    ///
    /// # Returns
    ///
    /// A JSON string representation of the run record.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Serializes the run record to pretty-printed JSON.
    ///
    /// # Returns
    ///
    /// A pretty-printed JSON string representation of the run record.
    pub fn to_json_pretty(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    /// Deserializes a run record from JSON.
    ///
    /// # Arguments
    ///
    /// * `json` - A JSON string representation of the run record
    ///
    /// # Returns
    ///
    /// The deserialized run record.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }

    /// Calculates the total distance covered in a sequence of points.
    fn calculate_total_distance(points: &[Point]) -> f64 {
        if points.len() < 2 {
            return 0.0;
        }

        points.windows(2).map(|w| w[0].distance_to(&w[1])).sum()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_run() -> Vec<Point> {
        vec![
            Point::new(40.7128, -74.0060, 0),
            Point::new(40.7132, -74.0057, 5000),
            Point::new(40.7136, -74.0054, 10000),
            Point::new(40.7140, -74.0051, 15000),
            Point::new(40.7144, -74.0048, 20000),
        ]
    }

    #[test]
    fn test_run_record_creation() {
        let coords = create_test_run();
        let record = RunRecord::new(
            "test-run-001".to_string(),
            "Test Run".to_string(),
            coords,
            1234567890000,
        );

        assert_eq!(record.id, "test-run-001");
        assert_eq!(record.name, "Test Run");
        assert!(record.total_distance_meters > 0.0);
        assert_eq!(record.duration_ms, 20000);
    }

    #[test]
    fn test_average_pace() {
        let coords = create_test_run();
        let record = RunRecord::new("test-run".to_string(), "Test".to_string(), coords, 0);

        let pace = record.average_pace_min_per_km();
        assert!(pace > 0.0);
    }

    #[test]
    fn test_average_speed() {
        let coords = create_test_run();
        let record = RunRecord::new("test-run".to_string(), "Test".to_string(), coords, 0);

        let speed = record.average_speed_kmh();
        assert!(speed > 0.0);
    }

    #[test]
    fn test_json_serialization() {
        let coords = create_test_run();
        let record = RunRecord::new("test-run".to_string(), "Test".to_string(), coords, 0);

        let json = record.to_json().unwrap();
        assert!(json.contains("test-run"));
        assert!(json.contains("Test"));

        let deserialized = RunRecord::from_json(&json).unwrap();
        assert_eq!(deserialized.id, record.id);
        assert_eq!(deserialized.name, record.name);
        assert_eq!(deserialized.coordinates.len(), record.coordinates.len());
    }

    #[test]
    fn test_empty_run() {
        let record = RunRecord::new("empty".to_string(), "Empty".to_string(), vec![], 0);

        assert_eq!(record.total_distance_meters, 0.0);
        assert_eq!(record.duration_ms, 0);
        assert_eq!(record.average_pace_min_per_km(), 0.0);
        assert_eq!(record.average_speed_kmh(), 0.0);
    }
}
