//! Personal Best (PB) tracking for activities.

use crate::activity::ActivityType;
use serde::{Deserialize, Serialize};

/// A personal best for a specific distance and activity type.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersonalBest {
    /// The activity type this PB is for.
    pub activity_type: ActivityType,
    /// The standard distance in meters (e.g., 5000.0 for 5K).
    pub distance_meters: f64,
    /// Best time to cover this distance in milliseconds.
    pub time_ms: u64,
    /// ID of the activity that achieved this PB.
    pub activity_id: String,
    /// Date this PB was set (epoch milliseconds).
    pub achieved_at: u64,
    /// Average pace in min/km for this segment.
    pub pace_min_per_km: f64,
}

impl PersonalBest {
    /// Creates a new PersonalBest record.
    pub fn new(
        activity_type: ActivityType,
        distance_meters: f64,
        time_ms: u64,
        activity_id: String,
        achieved_at: u64,
    ) -> Self {
        let pace_min_per_km = (time_ms as f64 / 60_000.0) / (distance_meters / 1000.0);
        Self {
            activity_type,
            distance_meters,
            time_ms,
            activity_id,
            achieved_at,
            pace_min_per_km,
        }
    }

    /// Formats the time as a human-readable string (HH:MM:SS or MM:SS).
    pub fn format_time(&self) -> String {
        let total_seconds = self.time_ms / 1000;
        let hours = total_seconds / 3600;
        let minutes = (total_seconds % 3600) / 60;
        let seconds = total_seconds % 60;

        if hours > 0 {
            format!("{}:{:02}:{:02}", hours, minutes, seconds)
        } else {
            format!("{}:{:02}", minutes, seconds)
        }
    }

    /// Formats the pace as a human-readable string (M:SS /km).
    pub fn format_pace(&self) -> String {
        let total_seconds = (self.pace_min_per_km * 60.0) as u64;
        let minutes = total_seconds / 60;
        let seconds = total_seconds % 60;
        format!("{}:{:02} /km", minutes, seconds)
    }

    /// Returns the human-readable name for this distance.
    pub fn distance_name(&self) -> &'static str {
        ActivityType::distance_name(self.distance_meters)
    }

    /// Serializes the PB to JSON.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Deserializes a PB from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}

/// Collection of all personal bests.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct PersonalBests {
    /// List of all PB records.
    pub records: Vec<PersonalBest>,
}

impl PersonalBests {
    /// Creates a new empty PersonalBests collection.
    pub fn new() -> Self {
        Self {
            records: Vec::new(),
        }
    }

    /// Gets the PB for a specific activity type and distance.
    pub fn get(&self, activity_type: ActivityType, distance_meters: f64) -> Option<&PersonalBest> {
        self.records.iter().find(|pb| {
            pb.activity_type == activity_type && (pb.distance_meters - distance_meters).abs() < 1.0
        })
    }

    /// Gets all PBs for a specific activity type.
    pub fn get_for_type(&self, activity_type: ActivityType) -> Vec<&PersonalBest> {
        self.records
            .iter()
            .filter(|pb| pb.activity_type == activity_type)
            .collect()
    }

    /// Updates or adds a PB. Returns true if this was a new PB.
    pub fn update(&mut self, pb: PersonalBest) -> bool {
        let existing_idx = self.records.iter().position(|existing| {
            existing.activity_type == pb.activity_type
                && (existing.distance_meters - pb.distance_meters).abs() < 1.0
        });

        match existing_idx {
            Some(idx) => {
                if pb.time_ms < self.records[idx].time_ms {
                    self.records[idx] = pb;
                    true
                } else {
                    false
                }
            }
            None => {
                self.records.push(pb);
                true
            }
        }
    }

    /// Removes all PBs for a specific activity.
    pub fn remove_for_activity(&mut self, activity_id: &str) {
        self.records.retain(|pb| pb.activity_id != activity_id);
    }

    /// Serializes the collection to JSON.
    pub fn to_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(self)
    }

    /// Serializes the collection to pretty-printed JSON.
    pub fn to_json_pretty(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string_pretty(self)
    }

    /// Deserializes a collection from JSON.
    pub fn from_json(json: &str) -> Result<Self, serde_json::Error> {
        serde_json::from_str(json)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_personal_best_creation() {
        let pb = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1200000, // 20 minutes
            "run-001".to_string(),
            1234567890000,
        );

        assert_eq!(pb.activity_type, ActivityType::Run);
        assert_eq!(pb.distance_meters, 5000.0);
        assert_eq!(pb.time_ms, 1200000);
        assert!((pb.pace_min_per_km - 4.0).abs() < 0.01); // 20 min / 5 km = 4 min/km
    }

    #[test]
    fn test_format_time() {
        let pb = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1265000, // 21:05
            "run-001".to_string(),
            0,
        );
        assert_eq!(pb.format_time(), "21:05");

        let pb_long = PersonalBest::new(
            ActivityType::Cycle,
            100000.0,
            14520000, // 4:02:00
            "cycle-001".to_string(),
            0,
        );
        assert_eq!(pb_long.format_time(), "4:02:00");
    }

    #[test]
    fn test_format_pace() {
        let pb = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1200000, // 20 minutes, 4:00/km pace
            "run-001".to_string(),
            0,
        );
        assert_eq!(pb.format_pace(), "4:00 /km");
    }

    #[test]
    fn test_personal_bests_update() {
        let mut pbs = PersonalBests::new();

        // Add first PB
        let pb1 = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1200000,
            "run-001".to_string(),
            1000,
        );
        assert!(pbs.update(pb1));
        assert_eq!(pbs.records.len(), 1);

        // Try to add slower PB (should not update)
        let pb2 = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1300000,
            "run-002".to_string(),
            2000,
        );
        assert!(!pbs.update(pb2));
        assert_eq!(pbs.records.len(), 1);
        assert_eq!(pbs.records[0].activity_id, "run-001");

        // Add faster PB (should update)
        let pb3 = PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1100000,
            "run-003".to_string(),
            3000,
        );
        assert!(pbs.update(pb3));
        assert_eq!(pbs.records.len(), 1);
        assert_eq!(pbs.records[0].activity_id, "run-003");
    }

    #[test]
    fn test_personal_bests_get_for_type() {
        let mut pbs = PersonalBests::new();
        pbs.update(PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1200000,
            "run-001".to_string(),
            0,
        ));
        pbs.update(PersonalBest::new(
            ActivityType::Run,
            10000.0,
            2500000,
            "run-002".to_string(),
            0,
        ));
        pbs.update(PersonalBest::new(
            ActivityType::Walk,
            5000.0,
            3000000,
            "walk-001".to_string(),
            0,
        ));

        let run_pbs = pbs.get_for_type(ActivityType::Run);
        assert_eq!(run_pbs.len(), 2);

        let walk_pbs = pbs.get_for_type(ActivityType::Walk);
        assert_eq!(walk_pbs.len(), 1);

        let cycle_pbs = pbs.get_for_type(ActivityType::Cycle);
        assert_eq!(cycle_pbs.len(), 0);
    }

    #[test]
    fn test_personal_bests_json() {
        let mut pbs = PersonalBests::new();
        pbs.update(PersonalBest::new(
            ActivityType::Run,
            5000.0,
            1200000,
            "run-001".to_string(),
            0,
        ));

        let json = pbs.to_json().unwrap();
        let deserialized = PersonalBests::from_json(&json).unwrap();

        assert_eq!(deserialized.records.len(), 1);
        assert_eq!(deserialized.records[0].activity_type, ActivityType::Run);
    }
}
