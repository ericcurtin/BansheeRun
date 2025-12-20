//! Personal Best calculation using sliding window algorithm.

use crate::activity::Activity;
use crate::personal_best::{PersonalBest, PersonalBests};
use crate::point::Point;

/// Result of PB calculation for a single distance.
#[derive(Debug, Clone)]
pub struct SegmentTime {
    /// The target distance in meters.
    pub distance_meters: f64,
    /// The best time to cover this distance in milliseconds.
    pub time_ms: u64,
    /// Start index of the segment in the coordinates array.
    pub start_idx: usize,
    /// End index of the segment in the coordinates array.
    pub end_idx: usize,
}

/// Calculates PBs achieved in activities.
pub struct PBCalculator;

impl PBCalculator {
    /// Extract the best time to cover each standard distance from the activity.
    pub fn calculate_segment_times(activity: &Activity) -> Vec<SegmentTime> {
        let target_distances = activity.activity_type.pb_distances();
        let mut results = Vec::new();

        // Build cumulative distance array once
        let cumulative = Self::build_cumulative_distances(&activity.coordinates);

        for &target_distance in target_distances {
            if activity.total_distance_meters >= target_distance {
                if let Some(segment) = Self::find_best_segment_time(
                    &activity.coordinates,
                    &cumulative,
                    target_distance,
                ) {
                    results.push(segment);
                }
            }
        }

        results
    }

    /// Build cumulative distance array from GPS points.
    fn build_cumulative_distances(points: &[Point]) -> Vec<f64> {
        let mut cumulative = vec![0.0];
        for i in 1..points.len() {
            let d = cumulative[i - 1] + points[i - 1].distance_to(&points[i]);
            cumulative.push(d);
        }
        cumulative
    }

    /// Find the fastest time to cover target_distance_m using sliding window.
    fn find_best_segment_time(
        points: &[Point],
        cumulative: &[f64],
        target_distance_m: f64,
    ) -> Option<SegmentTime> {
        if points.len() < 2 {
            return None;
        }

        // Total distance check
        if *cumulative.last()? < target_distance_m {
            return None;
        }

        let mut best_segment: Option<SegmentTime> = None;
        let mut end_idx = 0;

        for start_idx in 0..points.len() {
            // Move end index until we cover target distance
            while end_idx < points.len()
                && cumulative[end_idx] - cumulative[start_idx] < target_distance_m
            {
                end_idx += 1;
            }

            if end_idx >= points.len() {
                break;
            }

            // Interpolate exact time at target distance
            let segment_time = Self::interpolate_time_at_distance(
                points,
                cumulative,
                start_idx,
                cumulative[start_idx] + target_distance_m,
            );

            if let Some(end_time) = segment_time {
                let elapsed = end_time.saturating_sub(points[start_idx].timestamp_ms);

                let is_better = match &best_segment {
                    Some(best) => elapsed < best.time_ms,
                    None => true,
                };

                if is_better {
                    best_segment = Some(SegmentTime {
                        distance_meters: target_distance_m,
                        time_ms: elapsed,
                        start_idx,
                        end_idx,
                    });
                }
            }
        }

        best_segment
    }

    /// Interpolate timestamp at exact distance using linear interpolation.
    fn interpolate_time_at_distance(
        points: &[Point],
        cumulative: &[f64],
        start_idx: usize,
        target_cumulative: f64,
    ) -> Option<u64> {
        for i in (start_idx + 1)..points.len() {
            if cumulative[i] >= target_cumulative {
                let prev = &points[i - 1];
                let curr = &points[i];
                let segment_dist = cumulative[i] - cumulative[i - 1];

                if segment_dist > 0.0 {
                    let ratio = (target_cumulative - cumulative[i - 1]) / segment_dist;
                    let time_diff = (curr.timestamp_ms as f64 - prev.timestamp_ms as f64) * ratio;
                    let time = prev.timestamp_ms + time_diff as u64;
                    return Some(time);
                }
            }
        }
        None
    }

    /// Check and update PBs after completing an activity.
    /// Returns a tuple of (updated PBs collection, list of new PBs achieved).
    pub fn update_pbs(
        existing_pbs: &PersonalBests,
        activity: &Activity,
    ) -> (PersonalBests, Vec<PersonalBest>) {
        let segment_times = Self::calculate_segment_times(activity);
        let mut new_pbs = existing_pbs.clone();
        let mut achieved_pbs = Vec::new();

        for segment in segment_times {
            let existing = new_pbs.get(activity.activity_type, segment.distance_meters);

            let is_new_pb = match existing {
                Some(pb) => segment.time_ms < pb.time_ms,
                None => true,
            };

            if is_new_pb {
                let new_pb = PersonalBest::new(
                    activity.activity_type,
                    segment.distance_meters,
                    segment.time_ms,
                    activity.id.clone(),
                    activity.recorded_at,
                );

                achieved_pbs.push(new_pb.clone());
                new_pbs.update(new_pb);
            }
        }

        (new_pbs, achieved_pbs)
    }

    /// Calculate PBs from an activity without comparing to existing PBs.
    /// Returns segment times for all standard distances covered.
    pub fn calculate_pbs_for_activity(activity: &Activity) -> Vec<PersonalBest> {
        let segment_times = Self::calculate_segment_times(activity);

        segment_times
            .into_iter()
            .map(|segment| {
                PersonalBest::new(
                    activity.activity_type,
                    segment.distance_meters,
                    segment.time_ms,
                    activity.id.clone(),
                    activity.recorded_at,
                )
            })
            .collect()
    }
}

/// Formats a pace value (minutes per km) as a human-readable string.
pub fn format_pace(distance_meters: f64, duration_ms: u64) -> String {
    if distance_meters == 0.0 || duration_ms == 0 {
        return "0:00 /km".to_string();
    }

    let duration_minutes = duration_ms as f64 / 60_000.0;
    let distance_km = distance_meters / 1000.0;
    let pace_min_per_km = duration_minutes / distance_km;

    let total_seconds = (pace_min_per_km * 60.0) as u64;
    let minutes = total_seconds / 60;
    let seconds = total_seconds % 60;

    format!("{}:{:02} /km", minutes, seconds)
}

/// Calculates speed in km/h.
pub fn calculate_speed_kmh(distance_meters: f64, duration_ms: u64) -> f64 {
    if duration_ms == 0 {
        return 0.0;
    }
    let duration_hours = duration_ms as f64 / 3_600_000.0;
    let distance_km = distance_meters / 1000.0;
    distance_km / duration_hours
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::activity::ActivityType;

    /// Creates a test activity with a known distance and time.
    /// Creates points along a roughly north-south line.
    fn create_test_activity(total_distance_km: f64, duration_min: f64) -> Activity {
        let num_points = 100;
        let distance_per_point_m = (total_distance_km * 1000.0) / num_points as f64;
        let time_per_point_ms = (duration_min * 60_000.0) / num_points as f64;

        // Calculate lat delta for desired distance (roughly 111km per degree)
        let lat_delta_per_point = distance_per_point_m / 111_000.0;

        let mut points = Vec::new();
        let start_lat = 40.7128;
        let start_lon = -74.0060;

        for i in 0..=num_points {
            points.push(Point::new(
                start_lat + (i as f64 * lat_delta_per_point),
                start_lon,
                (i as f64 * time_per_point_ms) as u64,
            ));
        }

        Activity::new(
            "test-activity".to_string(),
            "Test Activity".to_string(),
            ActivityType::Run,
            points,
            1234567890000,
        )
    }

    #[test]
    fn test_build_cumulative_distances() {
        let points = vec![
            Point::new(40.7128, -74.0060, 0),
            Point::new(40.7137, -74.0060, 5000),  // ~100m north
            Point::new(40.7146, -74.0060, 10000), // ~100m more north
        ];

        let cumulative = PBCalculator::build_cumulative_distances(&points);

        assert_eq!(cumulative.len(), 3);
        assert_eq!(cumulative[0], 0.0);
        assert!(cumulative[1] > 90.0 && cumulative[1] < 110.0);
        assert!(cumulative[2] > 180.0 && cumulative[2] < 220.0);
    }

    #[test]
    fn test_calculate_segment_times_short_activity() {
        // Create a 500m activity - should not have any PBs (minimum is 1K)
        let activity = Activity::new(
            "short".to_string(),
            "Short Run".to_string(),
            ActivityType::Run,
            vec![
                Point::new(40.7128, -74.0060, 0),
                Point::new(40.7173, -74.0060, 180000), // ~500m, 3 min
            ],
            0,
        );

        let segments = PBCalculator::calculate_segment_times(&activity);
        assert!(segments.is_empty());
    }

    #[test]
    fn test_calculate_segment_times_1k() {
        // Create a 1.5km activity in 10 minutes
        let activity = create_test_activity(1.5, 10.0);

        let segments = PBCalculator::calculate_segment_times(&activity);

        // Should find a 1K segment
        assert!(segments
            .iter()
            .any(|s| (s.distance_meters - 1000.0).abs() < 1.0));

        // The 1K time should be roughly 2/3 of 10 minutes (6.67 min for 1km in a 1.5km/10min run)
        let one_k = segments
            .iter()
            .find(|s| (s.distance_meters - 1000.0).abs() < 1.0)
            .unwrap();
        let time_minutes = one_k.time_ms as f64 / 60_000.0;
        assert!(time_minutes > 5.0 && time_minutes < 8.0);
    }

    #[test]
    fn test_calculate_segment_times_5k() {
        // Create a 6km activity in 30 minutes
        let activity = create_test_activity(6.0, 30.0);

        let segments = PBCalculator::calculate_segment_times(&activity);

        // Should find 1K and 5K segments
        assert!(segments
            .iter()
            .any(|s| (s.distance_meters - 1000.0).abs() < 1.0));
        assert!(segments
            .iter()
            .any(|s| (s.distance_meters - 5000.0).abs() < 1.0));

        // 5K time should be roughly 25 minutes (5/6 of 30 min)
        let five_k = segments
            .iter()
            .find(|s| (s.distance_meters - 5000.0).abs() < 1.0)
            .unwrap();
        let time_minutes = five_k.time_ms as f64 / 60_000.0;
        assert!(time_minutes > 20.0 && time_minutes < 30.0);
    }

    #[test]
    fn test_update_pbs_empty() {
        let activity = create_test_activity(6.0, 30.0);
        let existing_pbs = PersonalBests::new();

        let (new_pbs, achieved) = PBCalculator::update_pbs(&existing_pbs, &activity);

        // Should achieve PBs for 1K and 5K
        assert!(achieved.len() >= 2);
        assert!(new_pbs.records.len() >= 2);
    }

    #[test]
    fn test_update_pbs_faster() {
        // First activity: 5km in 30 minutes
        let activity1 = create_test_activity(6.0, 30.0);
        let (pbs_after_1, _) = PBCalculator::update_pbs(&PersonalBests::new(), &activity1);

        // Second activity: 5km in 25 minutes (faster)
        let mut activity2 = create_test_activity(6.0, 25.0);
        activity2.id = "fast-run".to_string();

        let (pbs_after_2, achieved) = PBCalculator::update_pbs(&pbs_after_1, &activity2);

        // Should achieve new PBs
        assert!(!achieved.is_empty());

        // The 5K PB should be from the second activity
        let five_k_pb = pbs_after_2.get(ActivityType::Run, 5000.0).unwrap();
        assert_eq!(five_k_pb.activity_id, "fast-run");
    }

    #[test]
    fn test_update_pbs_slower() {
        // First activity: 5km in 25 minutes
        let activity1 = create_test_activity(6.0, 25.0);
        let (pbs_after_1, _) = PBCalculator::update_pbs(&PersonalBests::new(), &activity1);

        // Second activity: 5km in 30 minutes (slower)
        let mut activity2 = create_test_activity(6.0, 30.0);
        activity2.id = "slow-run".to_string();

        let (pbs_after_2, achieved) = PBCalculator::update_pbs(&pbs_after_1, &activity2);

        // Should NOT achieve new PBs for these distances
        assert!(achieved.is_empty());

        // The 5K PB should still be from the first activity
        let five_k_pb = pbs_after_2.get(ActivityType::Run, 5000.0).unwrap();
        assert_eq!(five_k_pb.activity_id, "test-activity");
    }

    #[test]
    fn test_format_pace() {
        assert_eq!(format_pace(5000.0, 1200000), "4:00 /km"); // 5km in 20min
        assert_eq!(format_pace(1000.0, 300000), "5:00 /km"); // 1km in 5min
        assert_eq!(format_pace(0.0, 1000), "0:00 /km");
    }

    #[test]
    fn test_calculate_speed_kmh() {
        // 10km in 1 hour = 10 km/h
        let speed = calculate_speed_kmh(10000.0, 3600000);
        assert!((speed - 10.0).abs() < 0.01);

        // 5km in 30 min = 10 km/h
        let speed2 = calculate_speed_kmh(5000.0, 1800000);
        assert!((speed2 - 10.0).abs() < 0.01);
    }

    #[test]
    fn test_cycling_pbs() {
        // Create a cycling activity
        let points: Vec<Point> = (0..=100)
            .map(|i| {
                Point::new(
                    40.7128 + (i as f64 * 0.001), // ~111m per point
                    -74.0060,
                    i * 40000, // 40 sec per point
                )
            })
            .collect();

        let activity = Activity::new(
            "cycle-001".to_string(),
            "Morning Ride".to_string(),
            ActivityType::Cycle,
            points,
            0,
        );

        let segments = PBCalculator::calculate_segment_times(&activity);

        // Cycling PBs start at 10K, our activity is only ~11km
        // Should find a 10K segment
        assert!(segments
            .iter()
            .any(|s| (s.distance_meters - 10000.0).abs() < 1.0));
    }
}
