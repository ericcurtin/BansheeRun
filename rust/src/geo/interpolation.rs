use chrono::{DateTime, Utc};

use crate::models::GpsPoint;

use super::distance::cumulative_distances;

/// Interpolate position at a specific elapsed time (in milliseconds) along a track
pub fn interpolate_position(points: &[GpsPoint], elapsed_ms: i64) -> Option<GpsPoint> {
    if points.is_empty() {
        return None;
    }

    if points.len() == 1 {
        return Some(points[0].clone());
    }

    let start_time = points[0].timestamp;
    let target_time = start_time + chrono::Duration::milliseconds(elapsed_ms);

    // Find the segment containing the target time
    for i in 0..points.len() - 1 {
        let p1 = &points[i];
        let p2 = &points[i + 1];

        if target_time >= p1.timestamp && target_time <= p2.timestamp {
            return Some(interpolate_between(p1, p2, target_time));
        }
    }

    // If beyond the last point, return the last point
    if elapsed_ms > 0 {
        Some(points.last().unwrap().clone())
    } else {
        Some(points[0].clone())
    }
}

/// Interpolate position at a specific distance (in meters) along a track
pub fn interpolate_position_at_distance(points: &[GpsPoint], distance_m: f64) -> Option<GpsPoint> {
    if points.is_empty() {
        return None;
    }

    if points.len() == 1 || distance_m <= 0.0 {
        return Some(points[0].clone());
    }

    let cumulative = cumulative_distances(points);
    let total_distance = *cumulative.last().unwrap_or(&0.0);

    if distance_m >= total_distance {
        return Some(points.last().unwrap().clone());
    }

    // Find the segment containing the target distance
    for i in 0..points.len() - 1 {
        let d1 = cumulative[i];
        let d2 = cumulative[i + 1];

        if distance_m >= d1 && distance_m <= d2 {
            let segment_length = d2 - d1;
            if segment_length < 0.001 {
                return Some(points[i].clone());
            }

            let fraction = (distance_m - d1) / segment_length;
            return Some(interpolate_by_fraction(
                &points[i],
                &points[i + 1],
                fraction,
            ));
        }
    }

    Some(points.last().unwrap().clone())
}

/// Interpolate between two points at a specific timestamp
fn interpolate_between(p1: &GpsPoint, p2: &GpsPoint, target_time: DateTime<Utc>) -> GpsPoint {
    let segment_duration = (p2.timestamp - p1.timestamp).num_milliseconds() as f64;

    if segment_duration <= 0.0 {
        return p1.clone();
    }

    let elapsed = (target_time - p1.timestamp).num_milliseconds() as f64;
    let fraction = (elapsed / segment_duration).clamp(0.0, 1.0);

    interpolate_by_fraction(p1, p2, fraction)
}

/// Interpolate between two points by a fraction (0.0 to 1.0)
fn interpolate_by_fraction(p1: &GpsPoint, p2: &GpsPoint, fraction: f64) -> GpsPoint {
    let lat = p1.lat + (p2.lat - p1.lat) * fraction;
    let lon = p1.lon + (p2.lon - p1.lon) * fraction;

    let altitude = match (p1.altitude, p2.altitude) {
        (Some(a1), Some(a2)) => Some(a1 + (a2 - a1) * fraction),
        (Some(a), None) | (None, Some(a)) => Some(a),
        (None, None) => None,
    };

    let speed = match (p1.speed, p2.speed) {
        (Some(s1), Some(s2)) => Some(s1 + (s2 - s1) * fraction),
        (Some(s), None) | (None, Some(s)) => Some(s),
        (None, None) => None,
    };

    let timestamp = p1.timestamp
        + chrono::Duration::milliseconds(
            ((p2.timestamp - p1.timestamp).num_milliseconds() as f64 * fraction) as i64,
        );

    GpsPoint {
        lat,
        lon,
        altitude,
        timestamp,
        accuracy: p1.accuracy, // Use accuracy from first point
        speed,
    }
}

/// Calculate elapsed time at a given distance along the track
pub fn time_at_distance(points: &[GpsPoint], distance_m: f64) -> Option<i64> {
    if points.is_empty() {
        return None;
    }

    if distance_m <= 0.0 {
        return Some(0);
    }

    let cumulative = cumulative_distances(points);
    let total_distance = *cumulative.last().unwrap_or(&0.0);

    if distance_m >= total_distance {
        let duration = points.last().unwrap().timestamp - points[0].timestamp;
        return Some(duration.num_milliseconds());
    }

    for i in 0..points.len() - 1 {
        let d1 = cumulative[i];
        let d2 = cumulative[i + 1];

        if distance_m >= d1 && distance_m <= d2 {
            let segment_length = d2 - d1;
            let segment_time =
                (points[i + 1].timestamp - points[i].timestamp).num_milliseconds() as f64;

            if segment_length > 0.001 {
                let fraction = (distance_m - d1) / segment_length;
                let base_time = (points[i].timestamp - points[0].timestamp).num_milliseconds();
                return Some(base_time + (segment_time * fraction) as i64);
            } else {
                return Some((points[i].timestamp - points[0].timestamp).num_milliseconds());
            }
        }
    }

    None
}

/// Calculate the distance covered at a given elapsed time
pub fn distance_at_time(points: &[GpsPoint], elapsed_ms: i64) -> f64 {
    if points.is_empty() || elapsed_ms <= 0 {
        return 0.0;
    }

    let start_time = points[0].timestamp;
    let target_time = start_time + chrono::Duration::milliseconds(elapsed_ms);

    let cumulative = cumulative_distances(points);

    for i in 0..points.len() - 1 {
        let p1 = &points[i];
        let p2 = &points[i + 1];

        if target_time >= p1.timestamp && target_time <= p2.timestamp {
            let segment_time = (p2.timestamp - p1.timestamp).num_milliseconds() as f64;
            if segment_time > 0.0 {
                let elapsed_in_segment = (target_time - p1.timestamp).num_milliseconds() as f64;
                let fraction = elapsed_in_segment / segment_time;
                let segment_distance = cumulative[i + 1] - cumulative[i];
                return cumulative[i] + segment_distance * fraction;
            }
            return cumulative[i];
        }
    }

    // Beyond last point
    *cumulative.last().unwrap_or(&0.0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{Duration, Utc};

    fn create_test_track() -> Vec<GpsPoint> {
        let start = Utc::now();
        vec![
            GpsPoint::new(51.5000, -0.1000, start),
            GpsPoint::new(51.5010, -0.1000, start + Duration::seconds(60)),
            GpsPoint::new(51.5020, -0.1000, start + Duration::seconds(120)),
            GpsPoint::new(51.5030, -0.1000, start + Duration::seconds(180)),
        ]
    }

    #[test]
    fn test_interpolate_at_start() {
        let points = create_test_track();
        let result = interpolate_position(&points, 0).unwrap();
        assert!((result.lat - 51.5000).abs() < 0.0001);
    }

    #[test]
    fn test_interpolate_midpoint() {
        let points = create_test_track();
        let result = interpolate_position(&points, 30_000).unwrap(); // 30 seconds
        assert!(result.lat > 51.5000 && result.lat < 51.5010);
    }

    #[test]
    fn test_interpolate_by_distance() {
        let points = create_test_track();
        let result = interpolate_position_at_distance(&points, 500.0).unwrap();
        assert!(result.lat > 51.5000);
    }
}
