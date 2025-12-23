use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};

/// A single GPS coordinate with timestamp and metadata
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct GpsPoint {
    /// Latitude in degrees (-90 to 90)
    pub lat: f64,
    /// Longitude in degrees (-180 to 180)
    pub lon: f64,
    /// Altitude in meters (optional)
    pub altitude: Option<f64>,
    /// Timestamp when this point was recorded
    pub timestamp: DateTime<Utc>,
    /// Horizontal accuracy in meters (optional)
    pub accuracy: Option<f64>,
    /// Speed in meters per second (optional)
    pub speed: Option<f64>,
}

impl GpsPoint {
    pub fn new(lat: f64, lon: f64, timestamp: DateTime<Utc>) -> Self {
        Self {
            lat,
            lon,
            altitude: None,
            timestamp,
            accuracy: None,
            speed: None,
        }
    }

    pub fn with_altitude(mut self, altitude: f64) -> Self {
        self.altitude = Some(altitude);
        self
    }

    pub fn with_accuracy(mut self, accuracy: f64) -> Self {
        self.accuracy = Some(accuracy);
        self
    }

    pub fn with_speed(mut self, speed: f64) -> Self {
        self.speed = Some(speed);
        self
    }
}
