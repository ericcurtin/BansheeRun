import Foundation

/// Swift wrapper for the BansheeRun Rust library.
enum BansheeLib {
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
}
