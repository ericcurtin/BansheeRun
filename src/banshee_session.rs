//! Banshee Session - Core pacing logic for comparing current run against a "banshee" (best run).

use crate::point::Point;

/// A banshee session that tracks the current run against a previous best run.
///
/// The "banshee" represents the runner's previous best performance, and this session
/// compares the current run in real-time to determine if the runner is ahead or behind.
#[derive(Debug, Clone)]
pub struct BansheeSession {
    /// The coordinates from the best run, loaded from storage.
    pub best_run_coords: Vec<Point>,
    /// Total distance covered in the best run (cached for performance).
    best_run_total_distance: f64,
}

/// Result of a pacing comparison.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PacingStatus {
    /// Runner is ahead of the banshee.
    Ahead,
    /// Runner is behind the banshee.
    Behind,
    /// Cannot determine (e.g., not enough data).
    Unknown,
}

impl BansheeSession {
    /// Creates a new BansheeSession with the given best run coordinates.
    ///
    /// # Arguments
    ///
    /// * `best_run_coords` - The GPS coordinates from the best run
    ///
    /// # Example
    ///
    /// ```
    /// use banshee_run::{BansheeSession, Point};
    ///
    /// let best_run = vec![
    ///     Point::new(40.7128, -74.0060, 0),
    ///     Point::new(40.7135, -74.0055, 10000),
    /// ];
    /// let session = BansheeSession::new(best_run);
    /// ```
    pub fn new(best_run_coords: Vec<Point>) -> Self {
        let best_run_total_distance = Self::calculate_total_distance(&best_run_coords);
        Self {
            best_run_coords,
            best_run_total_distance,
        }
    }

    /// Returns the total distance of the best run in meters.
    pub fn best_run_distance(&self) -> f64 {
        self.best_run_total_distance
    }

    /// Returns the duration of the best run in milliseconds.
    pub fn best_run_duration_ms(&self) -> u64 {
        self.best_run_coords
            .last()
            .map(|p| p.timestamp_ms)
            .unwrap_or(0)
    }

    /// Checks if the runner is behind the banshee at the current position and time.
    ///
    /// # Arguments
    ///
    /// * `current_pos` - The runner's current GPS position
    /// * `elapsed_ms` - Milliseconds elapsed since the start of the run
    ///
    /// # Returns
    ///
    /// `true` if the banshee is further ahead, `false` otherwise.
    ///
    /// # Example
    ///
    /// ```
    /// use banshee_run::{BansheeSession, Point};
    ///
    /// let best_run = vec![
    ///     Point::new(40.7128, -74.0060, 0),
    ///     Point::new(40.7135, -74.0055, 10000),
    ///     Point::new(40.7142, -74.0050, 20000),
    /// ];
    /// let session = BansheeSession::new(best_run);
    ///
    /// // Current position after 15 seconds
    /// let current = Point::new(40.7130, -74.0058, 15000);
    /// let is_behind = session.is_behind(&current, 15000);
    /// ```
    pub fn is_behind(&self, current_pos: &Point, elapsed_ms: u64) -> bool {
        matches!(
            self.get_pacing_status(current_pos, elapsed_ms),
            PacingStatus::Behind
        )
    }

    /// Gets the detailed pacing status comparing current position to the banshee.
    ///
    /// # Arguments
    ///
    /// * `current_pos` - The runner's current GPS position
    /// * `elapsed_ms` - Milliseconds elapsed since the start of the run
    ///
    /// # Returns
    ///
    /// A `PacingStatus` indicating whether the runner is ahead, behind, or unknown.
    pub fn get_pacing_status(&self, current_pos: &Point, elapsed_ms: u64) -> PacingStatus {
        if self.best_run_coords.is_empty() {
            return PacingStatus::Unknown;
        }

        // Get banshee position at the elapsed time
        let banshee_distance = self.get_banshee_distance_at_time(elapsed_ms);

        // Calculate current distance from start
        let current_distance = self.calculate_distance_from_start(current_pos);

        if banshee_distance > current_distance {
            PacingStatus::Behind
        } else {
            PacingStatus::Ahead
        }
    }

    /// Gets the time difference between the runner and the banshee at the current position.
    ///
    /// # Arguments
    ///
    /// * `current_pos` - The runner's current GPS position
    /// * `elapsed_ms` - Milliseconds elapsed since the start of the run
    ///
    /// # Returns
    ///
    /// The time difference in milliseconds. Positive means the runner is ahead,
    /// negative means the runner is behind.
    pub fn get_time_difference_ms(&self, current_pos: &Point, elapsed_ms: u64) -> i64 {
        if self.best_run_coords.is_empty() {
            return 0;
        }

        let current_distance = self.calculate_distance_from_start(current_pos);
        let banshee_time_at_distance = self.get_banshee_time_at_distance(current_distance);

        elapsed_ms as i64 - banshee_time_at_distance as i64
    }

    /// Calculates the total distance covered in a sequence of points.
    fn calculate_total_distance(points: &[Point]) -> f64 {
        if points.len() < 2 {
            return 0.0;
        }

        points.windows(2).map(|w| w[0].distance_to(&w[1])).sum()
    }

    /// Gets the banshee's distance from start at a given elapsed time.
    fn get_banshee_distance_at_time(&self, elapsed_ms: u64) -> f64 {
        if self.best_run_coords.is_empty() {
            return 0.0;
        }

        // Find the two points that bracket the elapsed time
        let mut cumulative_distance = 0.0;

        for i in 0..self.best_run_coords.len() {
            if self.best_run_coords[i].timestamp_ms >= elapsed_ms {
                if i == 0 {
                    return 0.0;
                }

                // Interpolate between points
                let prev = &self.best_run_coords[i - 1];
                let curr = &self.best_run_coords[i];

                let segment_distance = prev.distance_to(curr);
                let time_ratio = if curr.timestamp_ms > prev.timestamp_ms {
                    (elapsed_ms - prev.timestamp_ms) as f64
                        / (curr.timestamp_ms - prev.timestamp_ms) as f64
                } else {
                    0.0
                };

                return cumulative_distance + segment_distance * time_ratio;
            }

            if i > 0 {
                cumulative_distance +=
                    self.best_run_coords[i - 1].distance_to(&self.best_run_coords[i]);
            }
        }

        // If elapsed time is beyond the best run, return total distance
        self.best_run_total_distance
    }

    /// Gets the banshee's time to reach a given distance.
    fn get_banshee_time_at_distance(&self, distance: f64) -> u64 {
        if self.best_run_coords.is_empty() {
            return 0;
        }

        let mut cumulative_distance = 0.0;

        for i in 1..self.best_run_coords.len() {
            let segment_distance =
                self.best_run_coords[i - 1].distance_to(&self.best_run_coords[i]);
            let new_cumulative = cumulative_distance + segment_distance;

            if new_cumulative >= distance {
                // Interpolate to find exact time
                let prev = &self.best_run_coords[i - 1];
                let curr = &self.best_run_coords[i];

                let distance_ratio = if segment_distance > 0.0 {
                    (distance - cumulative_distance) / segment_distance
                } else {
                    0.0
                };

                let time_diff = curr.timestamp_ms.saturating_sub(prev.timestamp_ms);
                return prev.timestamp_ms + (time_diff as f64 * distance_ratio) as u64;
            }

            cumulative_distance = new_cumulative;
        }

        // If distance is beyond the best run, return the final time
        self.best_run_duration_ms()
    }

    /// Calculates the current distance from the start point of the best run.
    fn calculate_distance_from_start(&self, current_pos: &Point) -> f64 {
        if self.best_run_coords.is_empty() {
            return 0.0;
        }

        // Find the closest point on the best run path to the current position
        // and calculate cumulative distance to that point
        let mut best_distance_along_path = 0.0;
        let mut min_perpendicular_distance = f64::MAX;
        let mut cumulative_distance = 0.0;

        for i in 0..self.best_run_coords.len() {
            let point = &self.best_run_coords[i];
            let distance_to_point = current_pos.distance_to(point);

            if distance_to_point < min_perpendicular_distance {
                min_perpendicular_distance = distance_to_point;
                best_distance_along_path = cumulative_distance;
            }

            if i > 0 {
                cumulative_distance += self.best_run_coords[i - 1].distance_to(point);
            }
        }

        best_distance_along_path
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn create_test_run() -> Vec<Point> {
        vec![
            Point::new(40.7128, -74.0060, 0),
            Point::new(40.7132, -74.0057, 5000), // ~50m, 5 seconds
            Point::new(40.7136, -74.0054, 10000), // ~100m, 10 seconds
            Point::new(40.7140, -74.0051, 15000), // ~150m, 15 seconds
            Point::new(40.7144, -74.0048, 20000), // ~200m, 20 seconds
        ]
    }

    #[test]
    fn test_banshee_session_creation() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords.clone());
        assert_eq!(session.best_run_coords.len(), 5);
        assert!(session.best_run_distance() > 0.0);
    }

    #[test]
    fn test_best_run_duration() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords);
        assert_eq!(session.best_run_duration_ms(), 20000);
    }

    #[test]
    fn test_pacing_status_at_start() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords.clone());

        // At the start, should be at same position
        let current = Point::new(40.7128, -74.0060, 0);
        let status = session.get_pacing_status(&current, 0);
        // At the exact start, we should be considered ahead (not behind)
        assert_ne!(status, PacingStatus::Behind);
    }

    #[test]
    fn test_pacing_status_behind() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords.clone());

        // Still at start after 10 seconds - should be behind
        let current = Point::new(40.7128, -74.0060, 10000);
        let status = session.get_pacing_status(&current, 10000);
        assert_eq!(status, PacingStatus::Behind);
    }

    #[test]
    fn test_pacing_status_ahead() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords.clone());

        // At position 4 (far ahead) after only 5 seconds - should be ahead
        let current = Point::new(40.7144, -74.0048, 5000);
        let status = session.get_pacing_status(&current, 5000);
        assert_eq!(status, PacingStatus::Ahead);
    }

    #[test]
    fn test_is_behind() {
        let coords = create_test_run();
        let session = BansheeSession::new(coords.clone());

        // Still at start after 10 seconds - should be behind
        let current = Point::new(40.7128, -74.0060, 10000);
        assert!(session.is_behind(&current, 10000));

        // At far position after 5 seconds - should not be behind
        let current = Point::new(40.7144, -74.0048, 5000);
        assert!(!session.is_behind(&current, 5000));
    }

    #[test]
    fn test_empty_best_run() {
        let session = BansheeSession::new(vec![]);
        let current = Point::new(40.7128, -74.0060, 10000);

        assert_eq!(
            session.get_pacing_status(&current, 10000),
            PacingStatus::Unknown
        );
        assert!(!session.is_behind(&current, 10000));
    }
}
