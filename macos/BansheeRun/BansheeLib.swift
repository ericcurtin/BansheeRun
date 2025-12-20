import Foundation

/// Swift wrapper for the BansheeRun Rust library.
enum BansheeLib {
    // MARK: - Types

    enum PacingStatus: Int32 {
        case ahead = 0
        case behind = 1
        case unknown = 2

        static func from(_ value: Int32) -> PacingStatus {
            switch value {
            case 0: return .ahead
            case 1: return .behind
            default: return .unknown
            }
        }
    }

    enum ActivityType: Int32, Codable, CaseIterable {
        case run = 0
        case walk = 1
        case cycle = 2
        case rollerSkate = 3

        var displayName: String {
            switch self {
            case .run: return "Run"
            case .walk: return "Walk"
            case .cycle: return "Cycle"
            case .rollerSkate: return "Skate"
            }
        }

        var icon: String {
            switch self {
            case .run: return "figure.run"
            case .walk: return "figure.walk"
            case .cycle: return "bicycle"
            case .rollerSkate: return "figure.skating"
            }
        }
    }

    // MARK: - Helper Functions

    /// Converts a C string pointer to a Swift String, then frees the C string.
    private static func stringFromCString(_ ptr: UnsafeMutablePointer<CChar>?) -> String? {
        guard let ptr = ptr else { return nil }
        let string = String(cString: ptr)
        banshee_free_string(ptr)
        return string
    }

    // MARK: - Session Management

    /// Initialize a session with a best run JSON.
    /// - Returns: 0 on success, negative on error
    static func initSession(json: String) -> Int32 {
        return json.withCString { ptr in
            banshee_init_session(ptr)
        }
    }

    /// Clear the current session.
    static func clearSession() {
        banshee_clear_session()
    }

    /// Check if runner is behind the banshee.
    /// - Returns: true if behind, false otherwise
    static func isBehind(lat: Double, lon: Double, elapsedMs: Int64) -> Bool {
        return banshee_is_behind(lat, lon, elapsedMs) == 1
    }

    /// Get pacing status.
    static func getPacingStatus(lat: Double, lon: Double, elapsedMs: Int64) -> PacingStatus {
        let status = banshee_get_pacing_status(lat, lon, elapsedMs)
        return PacingStatus.from(status)
    }

    /// Get time difference in milliseconds (positive = ahead, negative = behind).
    static func getTimeDifferenceMs(lat: Double, lon: Double, elapsedMs: Int64) -> Int64 {
        return banshee_get_time_difference_ms(lat, lon, elapsedMs)
    }

    /// Get best run total distance in meters.
    static func getBestRunDistance() -> Double {
        return banshee_get_best_run_distance()
    }

    /// Get best run duration in milliseconds.
    static func getBestRunDurationMs() -> Int64 {
        return banshee_get_best_run_duration_ms()
    }

    // MARK: - Activity Management

    /// Create an Activity JSON with the specified type.
    static func createActivityJson(
        id: String,
        name: String,
        activityType: ActivityType,
        coordsJson: String,
        recordedAt: Int64
    ) -> String? {
        return id.withCString { idPtr in
            name.withCString { namePtr in
                coordsJson.withCString { coordsPtr in
                    let ptr = banshee_create_activity_json(
                        idPtr,
                        namePtr,
                        activityType.rawValue,
                        coordsPtr,
                        recordedAt
                    )
                    return stringFromCString(ptr)
                }
            }
        }
    }

    /// Get an ActivitySummary JSON from an Activity JSON.
    static func getActivitySummary(activityJson: String) -> String? {
        return activityJson.withCString { ptr in
            let resultPtr = banshee_get_activity_summary(ptr)
            return stringFromCString(resultPtr)
        }
    }

    // MARK: - Personal Bests

    /// Calculate PBs from an activity JSON.
    static func calculateActivityPbs(activityJson: String) -> String? {
        return activityJson.withCString { ptr in
            let resultPtr = banshee_calculate_activity_pbs(ptr)
            return stringFromCString(resultPtr)
        }
    }

    /// Update PBs with a new activity.
    static func updatePbs(existingPbsJson: String?, activityJson: String) -> String? {
        return activityJson.withCString { activityPtr in
            if let existingJson = existingPbsJson {
                return existingJson.withCString { existingPtr in
                    let resultPtr = banshee_update_pbs(existingPtr, activityPtr)
                    return stringFromCString(resultPtr)
                }
            } else {
                let resultPtr = banshee_update_pbs(nil, activityPtr)
                return stringFromCString(resultPtr)
            }
        }
    }

    /// Get new PBs achieved in an activity.
    static func getNewPbs(existingPbsJson: String?, activityJson: String) -> String? {
        return activityJson.withCString { activityPtr in
            if let existingJson = existingPbsJson {
                return existingJson.withCString { existingPtr in
                    let resultPtr = banshee_get_new_pbs(existingPtr, activityPtr)
                    return stringFromCString(resultPtr)
                }
            } else {
                let resultPtr = banshee_get_new_pbs(nil, activityPtr)
                return stringFromCString(resultPtr)
            }
        }
    }

    /// Get all PBs for a specific activity type.
    static func getPbsForType(pbsJson: String, activityType: ActivityType) -> String? {
        return pbsJson.withCString { ptr in
            let resultPtr = banshee_get_pbs_for_type(ptr, activityType.rawValue)
            return stringFromCString(resultPtr)
        }
    }

    // MARK: - Activity Index

    /// Sort activities in an index by date (most recent first).
    static func sortActivitiesByDate(indexJson: String) -> String? {
        return indexJson.withCString { ptr in
            let resultPtr = banshee_sort_activities_by_date(ptr)
            return stringFromCString(resultPtr)
        }
    }

    /// Filter activities by type. Pass nil for all activities.
    static func filterActivitiesByType(indexJson: String, activityType: ActivityType?) -> String? {
        let typeValue: Int32 = activityType?.rawValue ?? -1
        return indexJson.withCString { ptr in
            let resultPtr = banshee_filter_activities_by_type(ptr, typeValue)
            return stringFromCString(resultPtr)
        }
    }

    // MARK: - Formatting Helpers

    /// Format pace for display.
    static func formatPace(distanceMeters: Double, durationMs: Int64) -> String {
        let ptr = banshee_format_pace(distanceMeters, durationMs)
        return stringFromCString(ptr) ?? "0:00 /km"
    }

    /// Calculate speed in km/h.
    static func calculateSpeedKmh(distanceMeters: Double, durationMs: Int64) -> Double {
        return banshee_calculate_speed_kmh(distanceMeters, durationMs)
    }

    /// Format time duration for display.
    static func formatDuration(durationMs: Int64) -> String {
        let ptr = banshee_format_duration(durationMs)
        return stringFromCString(ptr) ?? "0:00"
    }

    /// Format distance for display.
    static func formatDistance(distanceMeters: Double) -> String {
        let ptr = banshee_format_distance(distanceMeters)
        return stringFromCString(ptr) ?? "0 m"
    }

    /// Get the human-readable name for a PB distance.
    static func getDistanceName(distanceMeters: Double) -> String {
        let ptr = banshee_get_distance_name(distanceMeters)
        return stringFromCString(ptr) ?? "Custom"
    }
}
