use crate::geo::interpolation;
use crate::models::{BansheeState, GpsPoint};
use chrono::{DateTime, Utc};

use super::run_api::get_run;

/// DTO for banshee state returned to Flutter
pub struct BansheeStateDto {
    pub lat: f64,
    pub lon: f64,
    pub distance_meters: f64,
    pub time_delta_ms: i64,
    pub distance_delta_meters: f64,
}

impl From<BansheeState> for BansheeStateDto {
    fn from(state: BansheeState) -> Self {
        Self {
            lat: state.lat,
            lon: state.lon,
            distance_meters: state.distance_meters,
            time_delta_ms: state.time_delta_ms,
            distance_delta_meters: state.distance_delta_meters,
        }
    }
}

/// Get banshee position for a recorded run at a given elapsed time
pub fn get_recorded_banshee_position(
    run_id: String,
    elapsed_ms: i64,
) -> Result<BansheeStateDto, String> {
    let run = get_run(run_id)?.ok_or_else(|| "Run not found".to_string())?;

    let points: Vec<GpsPoint> = run
        .points
        .into_iter()
        .map(|p| {
            let timestamp = DateTime::from_timestamp_millis(p.timestamp_ms)
                .map(|dt| dt.with_timezone(&Utc))
                .unwrap_or_else(Utc::now);

            GpsPoint {
                lat: p.lat,
                lon: p.lon,
                altitude: p.altitude,
                timestamp,
                accuracy: p.accuracy,
                speed: p.speed,
            }
        })
        .collect();

    if points.is_empty() {
        return Err("Run has no GPS points".to_string());
    }

    let position = interpolation::interpolate_position(&points, elapsed_ms)
        .ok_or_else(|| "Could not interpolate position".to_string())?;

    let distance = interpolation::distance_at_time(&points, elapsed_ms);

    Ok(BansheeStateDto {
        lat: position.lat,
        lon: position.lon,
        distance_meters: distance,
        time_delta_ms: 0,
        distance_delta_meters: 0.0,
    })
}

/// Get AI pacer position given start point, target pace, and elapsed time
/// The pacer follows the provided route if given, otherwise moves in a straight line
pub fn get_ai_pacer_position(
    start_lat: f64,
    start_lon: f64,
    target_pace_sec_per_km: f64,
    elapsed_ms: i64,
    route: Option<Vec<(f64, f64)>>,
) -> Result<BansheeStateDto, String> {
    if target_pace_sec_per_km <= 0.0 {
        return Err("Invalid pace".to_string());
    }

    // Calculate distance the pacer should have covered
    let elapsed_sec = elapsed_ms as f64 / 1000.0;
    let speed_m_per_sec = 1000.0 / target_pace_sec_per_km;
    let distance_meters = speed_m_per_sec * elapsed_sec;

    let (lat, lon) = if let Some(route_points) = route {
        if route_points.is_empty() {
            (start_lat, start_lon)
        } else {
            // Convert route to GpsPoints for interpolation
            let now = Utc::now();
            let gps_points: Vec<GpsPoint> = route_points
                .into_iter()
                .map(|(lat, lon)| GpsPoint::new(lat, lon, now))
                .collect();

            match interpolation::interpolate_position_at_distance(&gps_points, distance_meters) {
                Some(point) => (point.lat, point.lon),
                None => {
                    // Beyond route, use last point
                    let last = gps_points.last().unwrap();
                    (last.lat, last.lon)
                }
            }
        }
    } else {
        // No route - just stay at start (or could move in a direction)
        (start_lat, start_lon)
    };

    Ok(BansheeStateDto {
        lat,
        lon,
        distance_meters,
        time_delta_ms: 0,
        distance_delta_meters: 0.0,
    })
}

/// Calculate banshee state relative to runner
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_banshee_delta(
    banshee_distance_m: f64,
    banshee_time_ms: i64,
    runner_distance_m: f64,
    runner_time_ms: i64,
    target_pace_sec_per_km: Option<f64>,
) -> BansheeStateDto {
    let distance_delta = banshee_distance_m - runner_distance_m;

    // For time delta, calculate based on pace
    let time_delta = if let Some(pace) = target_pace_sec_per_km {
        // Time it would take runner to cover the distance gap at banshee's pace
        let speed = 1000.0 / pace; // m/s
        if speed > 0.0 {
            ((distance_delta / speed) * 1000.0) as i64
        } else {
            0
        }
    } else {
        banshee_time_ms - runner_time_ms
    };

    BansheeStateDto {
        lat: 0.0,
        lon: 0.0,
        distance_meters: banshee_distance_m,
        time_delta_ms: time_delta,
        distance_delta_meters: distance_delta,
    }
}

/// Format banshee delta for display (e.g., "50m behind", "100m ahead")
#[flutter_rust_bridge::frb(sync)]
pub fn format_banshee_delta(distance_delta_meters: f64) -> String {
    let abs_distance = distance_delta_meters.abs();
    let direction = if distance_delta_meters > 0.0 {
        "behind"
    } else {
        "ahead"
    };

    if abs_distance < 1.0 {
        "Even".to_string()
    } else if abs_distance < 1000.0 {
        format!("{:.0}m {}", abs_distance, direction)
    } else {
        format!("{:.2}km {}", abs_distance / 1000.0, direction)
    }
}

/// Check if the runner has crossed the ahead/behind threshold
/// Returns: -1 if now behind (was ahead), 1 if now ahead (was behind), 0 if no change
#[flutter_rust_bridge::frb(sync)]
pub fn check_position_change(previous_delta_m: f64, current_delta_m: f64, threshold_m: f64) -> i32 {
    let was_ahead = previous_delta_m < -threshold_m;
    let was_behind = previous_delta_m > threshold_m;
    let is_ahead = current_delta_m < -threshold_m;
    let is_behind = current_delta_m > threshold_m;

    if was_ahead && is_behind {
        -1 // Fell behind
    } else if was_behind && is_ahead {
        1 // Pulled ahead
    } else {
        0 // No significant change
    }
}

/// Generate common pace targets (returns pace in sec/km and display name)
#[flutter_rust_bridge::frb(sync)]
pub fn get_pace_presets() -> Vec<(f64, String)> {
    vec![
        (240.0, "4:00/km (Elite)".to_string()),
        (270.0, "4:30/km".to_string()),
        (300.0, "5:00/km".to_string()),
        (330.0, "5:30/km".to_string()),
        (360.0, "6:00/km".to_string()),
        (390.0, "6:30/km".to_string()),
        (420.0, "7:00/km".to_string()),
        (480.0, "8:00/km".to_string()),
        (540.0, "9:00/km".to_string()),
        (600.0, "10:00/km".to_string()),
    ]
}
