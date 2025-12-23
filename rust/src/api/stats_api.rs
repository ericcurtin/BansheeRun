use crate::geo::{self, pace};

/// Split information DTO for Flutter
pub struct SplitDto {
    pub number: i32,
    pub distance_m: f64,
    pub duration_ms: i64,
    pub pace_sec_per_km: f64,
    pub cumulative_distance_m: f64,
    pub cumulative_time_ms: i64,
    pub pace_formatted: String,
}

impl From<pace::Split> for SplitDto {
    fn from(split: pace::Split) -> Self {
        Self {
            number: split.number,
            distance_m: split.distance_m,
            duration_ms: split.duration_ms,
            pace_sec_per_km: split.pace_sec_per_km,
            cumulative_distance_m: split.cumulative_distance_m,
            cumulative_time_ms: split.cumulative_time_ms,
            pace_formatted: pace::format_pace(split.pace_sec_per_km),
        }
    }
}

/// Calculate distance between two GPS points
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_distance(lat1: f64, lon1: f64, lat2: f64, lon2: f64) -> f64 {
    geo::haversine_distance(lat1, lon1, lat2, lon2)
}

/// Calculate total distance from a list of GPS points
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_total_distance(points: Vec<(f64, f64)>) -> f64 {
    if points.len() < 2 {
        return 0.0;
    }

    points
        .windows(2)
        .map(|pair| geo::haversine_distance(pair[0].0, pair[0].1, pair[1].0, pair[1].1))
        .sum()
}

/// Calculate pace from distance (meters) and duration (milliseconds)
/// Returns pace in seconds per kilometer
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_pace(distance_m: f64, duration_ms: i64) -> f64 {
    pace::calculate_pace(distance_m, duration_ms)
}

/// Calculate pace per mile from distance (meters) and duration (milliseconds)
#[flutter_rust_bridge::frb(sync)]
pub fn calculate_pace_per_mile(distance_m: f64, duration_ms: i64) -> f64 {
    pace::calculate_pace_per_mile(distance_m, duration_ms)
}

/// Format pace (seconds per km) as MM:SS string
#[flutter_rust_bridge::frb(sync)]
pub fn format_pace(pace_sec_per_km: f64) -> String {
    pace::format_pace(pace_sec_per_km)
}

/// Format pace for miles
#[flutter_rust_bridge::frb(sync)]
pub fn format_pace_per_mile(pace_sec_per_km: f64) -> String {
    pace::format_pace_per_mile(pace_sec_per_km)
}

/// Convert speed (m/s) to pace (sec/km)
#[flutter_rust_bridge::frb(sync)]
pub fn speed_to_pace(speed_mps: f64) -> f64 {
    pace::speed_to_pace(speed_mps)
}

/// Convert pace (sec/km) to speed (m/s)
#[flutter_rust_bridge::frb(sync)]
pub fn pace_to_speed(pace_sec_per_km: f64) -> f64 {
    pace::pace_to_speed(pace_sec_per_km)
}

/// Format duration (milliseconds) as HH:MM:SS or MM:SS
#[flutter_rust_bridge::frb(sync)]
pub fn format_duration(duration_ms: i64) -> String {
    let total_secs = duration_ms / 1000;
    let hours = total_secs / 3600;
    let minutes = (total_secs % 3600) / 60;
    let seconds = total_secs % 60;

    if hours > 0 {
        format!("{}:{:02}:{:02}", hours, minutes, seconds)
    } else {
        format!("{}:{:02}", minutes, seconds)
    }
}

/// Format distance in meters to a human-readable string
#[flutter_rust_bridge::frb(sync)]
pub fn format_distance_km(distance_m: f64) -> String {
    if distance_m < 1000.0 {
        format!("{:.0} m", distance_m)
    } else {
        format!("{:.2} km", distance_m / 1000.0)
    }
}

/// Format distance in meters to miles
#[flutter_rust_bridge::frb(sync)]
pub fn format_distance_miles(distance_m: f64) -> String {
    let miles = distance_m / 1609.344;
    if miles < 0.1 {
        let feet = distance_m * 3.28084;
        format!("{:.0} ft", feet)
    } else {
        format!("{:.2} mi", miles)
    }
}

/// Calculate estimated finish time based on current pace
/// target_distance_m: target distance in meters
/// current_distance_m: current distance covered in meters
/// current_duration_ms: current duration in milliseconds
#[flutter_rust_bridge::frb(sync)]
pub fn estimate_finish_time(
    target_distance_m: f64,
    current_distance_m: f64,
    current_duration_ms: i64,
) -> Option<i64> {
    if current_distance_m <= 0.0 || current_duration_ms <= 0 {
        return None;
    }

    let current_pace = current_duration_ms as f64 / current_distance_m;
    let estimated_total = (target_distance_m * current_pace) as i64;

    Some(estimated_total)
}

/// Calculate calories burned (rough estimate)
/// weight_kg: runner's weight in kilograms
/// distance_m: distance covered in meters
/// Uses MET value of ~10 for running
#[flutter_rust_bridge::frb(sync)]
pub fn estimate_calories(weight_kg: f64, distance_m: f64) -> f64 {
    // Rough estimate: ~1 kcal per kg per km
    let distance_km = distance_m / 1000.0;
    weight_kg * distance_km * 1.0
}

/// Calculate projected distance at target time based on current pace
#[flutter_rust_bridge::frb(sync)]
pub fn project_distance_at_time(
    current_distance_m: f64,
    current_duration_ms: i64,
    target_duration_ms: i64,
) -> f64 {
    if current_duration_ms <= 0 {
        return 0.0;
    }

    let speed = current_distance_m / (current_duration_ms as f64);
    speed * (target_duration_ms as f64)
}
