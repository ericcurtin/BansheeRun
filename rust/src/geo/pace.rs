use crate::models::GpsPoint;

use super::distance::cumulative_distances;

/// A split (e.g., per kilometer or per mile)
#[derive(Debug, Clone)]
pub struct Split {
    /// Split number (1-indexed)
    pub number: i32,
    /// Distance of this split in meters
    pub distance_m: f64,
    /// Duration of this split in milliseconds
    pub duration_ms: i64,
    /// Pace in seconds per kilometer
    pub pace_sec_per_km: f64,
    /// Cumulative distance at the end of this split
    pub cumulative_distance_m: f64,
    /// Cumulative time at the end of this split
    pub cumulative_time_ms: i64,
}

/// Calculate pace in seconds per kilometer
pub fn calculate_pace(distance_m: f64, duration_ms: i64) -> f64 {
    if distance_m <= 0.0 || duration_ms <= 0 {
        return 0.0;
    }

    let distance_km = distance_m / 1000.0;
    let duration_sec = duration_ms as f64 / 1000.0;

    duration_sec / distance_km
}

/// Calculate pace in seconds per mile
pub fn calculate_pace_per_mile(distance_m: f64, duration_ms: i64) -> f64 {
    if distance_m <= 0.0 || duration_ms <= 0 {
        return 0.0;
    }

    let distance_miles = distance_m / 1609.344;
    let duration_sec = duration_ms as f64 / 1000.0;

    duration_sec / distance_miles
}

/// Format pace as MM:SS per km
pub fn format_pace(pace_sec_per_km: f64) -> String {
    if pace_sec_per_km <= 0.0 || pace_sec_per_km.is_nan() || pace_sec_per_km.is_infinite() {
        return "--:--".to_string();
    }

    let total_seconds = pace_sec_per_km as i64;
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;

    format!("{}:{:02}", minutes, seconds)
}

/// Format pace as MM:SS per mile
pub fn format_pace_per_mile(pace_sec_per_km: f64) -> String {
    let pace_per_mile = pace_sec_per_km * 1.60934;
    format_pace(pace_per_mile)
}

/// Calculate splits for a track
pub fn calculate_splits(points: &[GpsPoint], split_distance_m: f64) -> Vec<Split> {
    if points.len() < 2 || split_distance_m <= 0.0 {
        return Vec::new();
    }

    let cumulative = cumulative_distances(points);
    let total_distance = *cumulative.last().unwrap_or(&0.0);

    if total_distance < split_distance_m {
        // Not enough distance for even one split
        return Vec::new();
    }

    let mut splits = Vec::new();
    let mut split_num = 1;
    let mut target_distance = split_distance_m;
    let mut prev_split_time_ms: i64 = 0;

    let start_time = points[0].timestamp;

    for i in 1..points.len() {
        if cumulative[i] >= target_distance {
            // Calculate time at this distance
            let segment_distance = cumulative[i] - cumulative[i - 1];
            let segment_time =
                (points[i].timestamp - points[i - 1].timestamp).num_milliseconds() as f64;

            let time_ms = if segment_distance > 0.001 {
                let fraction = (target_distance - cumulative[i - 1]) / segment_distance;
                let base_time = (points[i - 1].timestamp - start_time).num_milliseconds() as f64;
                (base_time + segment_time * fraction) as i64
            } else {
                (points[i].timestamp - start_time).num_milliseconds()
            };

            let split_duration = time_ms - prev_split_time_ms;
            let pace = calculate_pace(split_distance_m, split_duration);

            splits.push(Split {
                number: split_num,
                distance_m: split_distance_m,
                duration_ms: split_duration,
                pace_sec_per_km: pace,
                cumulative_distance_m: target_distance,
                cumulative_time_ms: time_ms,
            });

            prev_split_time_ms = time_ms;
            split_num += 1;
            target_distance += split_distance_m;
        }
    }

    splits
}

/// Calculate current speed in meters per second from recent GPS points
pub fn current_speed(points: &[GpsPoint], window_size: usize) -> f64 {
    if points.len() < 2 {
        return 0.0;
    }

    let start_idx = points.len().saturating_sub(window_size);
    let window = &points[start_idx..];

    if window.len() < 2 {
        return 0.0;
    }

    let first = &window[0];
    let last = &window[window.len() - 1];

    let distance = super::distance::haversine_distance_points(first, last);
    let time_ms = (last.timestamp - first.timestamp).num_milliseconds();

    if time_ms <= 0 {
        return 0.0;
    }

    distance / (time_ms as f64 / 1000.0)
}

/// Convert speed (m/s) to pace (sec/km)
pub fn speed_to_pace(speed_mps: f64) -> f64 {
    if speed_mps <= 0.0 {
        return 0.0;
    }
    1000.0 / speed_mps
}

/// Convert pace (sec/km) to speed (m/s)
pub fn pace_to_speed(pace_sec_per_km: f64) -> f64 {
    if pace_sec_per_km <= 0.0 {
        return 0.0;
    }
    1000.0 / pace_sec_per_km
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_pace() {
        // 5km in 25 minutes = 300 seconds per km
        let pace = calculate_pace(5000.0, 25 * 60 * 1000);
        assert!((pace - 300.0).abs() < 0.1);
    }

    #[test]
    fn test_format_pace() {
        assert_eq!(format_pace(300.0), "5:00");
        assert_eq!(format_pace(330.0), "5:30");
        assert_eq!(format_pace(420.0), "7:00");
    }

    #[test]
    fn test_speed_pace_conversion() {
        let speed = 3.33; // ~12 km/h
        let pace = speed_to_pace(speed);
        let back_to_speed = pace_to_speed(pace);
        assert!((speed - back_to_speed).abs() < 0.01);
    }
}
