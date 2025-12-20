//! GPS Point representation and distance calculations.
//!
//! Uses the Haversine formula for calculating distances between GPS coordinates.

use serde::{Deserialize, Serialize};

/// Earth's radius in meters.
const EARTH_RADIUS_METERS: f64 = 6_371_000.0;

/// A GPS coordinate point with latitude, longitude, and timestamp.
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Point {
    /// Latitude in degrees (-90 to 90).
    pub lat: f64,
    /// Longitude in degrees (-180 to 180).
    pub lon: f64,
    /// Timestamp in milliseconds since the start of the run.
    pub timestamp_ms: u64,
}

impl Point {
    /// Creates a new Point with the given coordinates and timestamp.
    ///
    /// # Arguments
    ///
    /// * `lat` - Latitude in degrees
    /// * `lon` - Longitude in degrees
    /// * `timestamp_ms` - Milliseconds since the start of the run
    ///
    /// # Example
    ///
    /// ```
    /// use banshee_run::Point;
    ///
    /// let point = Point::new(40.7128, -74.0060, 0);
    /// assert_eq!(point.lat, 40.7128);
    /// ```
    pub fn new(lat: f64, lon: f64, timestamp_ms: u64) -> Self {
        Self {
            lat,
            lon,
            timestamp_ms,
        }
    }

    /// Calculates the distance in meters to another point using the Haversine formula.
    ///
    /// # Arguments
    ///
    /// * `other` - The other point to calculate distance to
    ///
    /// # Returns
    ///
    /// Distance in meters between the two points.
    ///
    /// # Example
    ///
    /// ```
    /// use banshee_run::Point;
    ///
    /// let nyc = Point::new(40.7128, -74.0060, 0);
    /// let la = Point::new(34.0522, -118.2437, 0);
    /// let distance = nyc.distance_to(&la);
    /// // Distance should be approximately 3935 km
    /// assert!(distance > 3_900_000.0 && distance < 4_000_000.0);
    /// ```
    pub fn distance_to(&self, other: &Point) -> f64 {
        let lat1_rad = self.lat.to_radians();
        let lat2_rad = other.lat.to_radians();
        let delta_lat = (other.lat - self.lat).to_radians();
        let delta_lon = (other.lon - self.lon).to_radians();

        let a = (delta_lat / 2.0).sin().powi(2)
            + lat1_rad.cos() * lat2_rad.cos() * (delta_lon / 2.0).sin().powi(2);
        let c = 2.0 * a.sqrt().asin();

        EARTH_RADIUS_METERS * c
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_point_creation() {
        let point = Point::new(40.7128, -74.0060, 1000);
        assert_eq!(point.lat, 40.7128);
        assert_eq!(point.lon, -74.0060);
        assert_eq!(point.timestamp_ms, 1000);
    }

    #[test]
    fn test_distance_same_point() {
        let point = Point::new(40.7128, -74.0060, 0);
        assert!((point.distance_to(&point) - 0.0).abs() < 0.001);
    }

    #[test]
    fn test_distance_known_points() {
        // New York City to Los Angeles
        let nyc = Point::new(40.7128, -74.0060, 0);
        let la = Point::new(34.0522, -118.2437, 0);
        let distance = nyc.distance_to(&la);
        // Expected distance is approximately 3935 km
        assert!(distance > 3_900_000.0 && distance < 4_000_000.0);
    }

    #[test]
    fn test_distance_short() {
        // Two points about 100 meters apart
        let p1 = Point::new(40.7128, -74.0060, 0);
        let p2 = Point::new(40.7137, -74.0060, 0); // ~100m north
        let distance = p1.distance_to(&p2);
        assert!(distance > 90.0 && distance < 110.0);
    }
}
