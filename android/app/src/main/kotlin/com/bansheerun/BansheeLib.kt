package com.bansheerun

/**
 * JNI wrapper for the BansheeRun Rust library.
 */
object BansheeLib {
    init {
        System.loadLibrary("banshee_run")
    }

    // ============================================================================
    // Enums
    // ============================================================================

    enum class PacingStatus {
        AHEAD,
        BEHIND,
        UNKNOWN;

        companion object {
            fun fromInt(value: Int): PacingStatus = when (value) {
                0 -> AHEAD
                1 -> BEHIND
                else -> UNKNOWN
            }
        }
    }

    enum class ActivityType(val value: Int) {
        RUN(0),
        WALK(1),
        CYCLE(2),
        ROLLER_SKATE(3);

        val displayName: String
            get() = when (this) {
                RUN -> "Run"
                WALK -> "Walk"
                CYCLE -> "Cycle"
                ROLLER_SKATE -> "Skate"
            }

        val icon: Int
            get() = when (this) {
                RUN -> android.R.drawable.ic_menu_mylocation
                WALK -> android.R.drawable.ic_menu_directions
                CYCLE -> android.R.drawable.ic_menu_compass
                ROLLER_SKATE -> android.R.drawable.ic_menu_rotate
            }

        companion object {
            fun fromInt(value: Int): ActivityType? = entries.find { it.value == value }
        }
    }

    // ============================================================================
    // Session Management (existing)
    // ============================================================================

    /**
     * Initialize a session with a best run JSON.
     * @return 0 on success, negative on error
     */
    @JvmStatic
    external fun initSession(json: String): Int

    /**
     * Clear the current session.
     */
    @JvmStatic
    external fun clearSession()

    /**
     * Check if runner is behind the banshee.
     * @return 1 = behind, 0 = not behind, -1 = no session
     */
    @JvmStatic
    external fun isBehind(lat: Double, lon: Double, elapsedMs: Long): Int

    /**
     * Get pacing status.
     * @return 0 = Ahead, 1 = Behind, 2 = Unknown, -1 = no session
     */
    @JvmStatic
    external fun getPacingStatus(lat: Double, lon: Double, elapsedMs: Long): Int

    /**
     * Get time difference in milliseconds (positive = ahead, negative = behind).
     */
    @JvmStatic
    external fun getTimeDifferenceMs(lat: Double, lon: Double, elapsedMs: Long): Long

    /**
     * Get best run total distance in meters.
     */
    @JvmStatic
    external fun getBestRunDistance(): Double

    /**
     * Get best run duration in milliseconds.
     */
    @JvmStatic
    external fun getBestRunDurationMs(): Long

    /**
     * Get banshee position at elapsed time.
     * @return DoubleArray of [lat, lon] or empty array if no session
     */
    @JvmStatic
    external fun getBansheePositionAtTime(elapsedMs: Long): DoubleArray

    /**
     * Get all best run coordinates as [lat1, lon1, lat2, lon2, ...].
     * @return DoubleArray of coordinates or empty array if no session
     */
    @JvmStatic
    external fun getBestRunCoordinates(): DoubleArray

    // ============================================================================
    // Activity Management
    // ============================================================================

    /**
     * Create an Activity JSON with the specified type.
     * @param activityType 0=Run, 1=Walk, 2=Cycle, 3=RollerSkate
     * @return Activity JSON string
     */
    @JvmStatic
    external fun createActivityJson(
        id: String,
        name: String,
        activityType: Int,
        coordsJson: String,
        recordedAt: Long
    ): String?

    /**
     * Get an ActivitySummary JSON from an Activity JSON.
     * @return ActivitySummary JSON string
     */
    @JvmStatic
    external fun getActivitySummary(activityJson: String): String?

    // ============================================================================
    // Personal Bests
    // ============================================================================

    /**
     * Calculate PBs from an activity JSON.
     * @return JSON array of PersonalBest records
     */
    @JvmStatic
    external fun calculateActivityPbs(activityJson: String): String?

    /**
     * Update PBs with a new activity.
     * @return Updated PBs JSON
     */
    @JvmStatic
    external fun updatePbs(existingPbsJson: String?, activityJson: String): String?

    /**
     * Get new PBs achieved in an activity.
     * @return JSON array of newly achieved PBs
     */
    @JvmStatic
    external fun getNewPbs(existingPbsJson: String?, activityJson: String): String?

    /**
     * Get all PBs for a specific activity type.
     * @return JSON array of PersonalBest records
     */
    @JvmStatic
    external fun getPbsForType(pbsJson: String, activityType: Int): String?

    // ============================================================================
    // Activity Index
    // ============================================================================

    /**
     * Sort activities in an index by date (most recent first).
     * @return Sorted ActivityIndex JSON
     */
    @JvmStatic
    external fun sortActivitiesByDate(indexJson: String): String?

    /**
     * Filter activities by type.
     * @param activityType 0=Run, 1=Walk, 2=Cycle, 3=RollerSkate, -1=All
     * @return Filtered ActivityIndex JSON
     */
    @JvmStatic
    external fun filterActivitiesByType(indexJson: String, activityType: Int): String?

    // ============================================================================
    // Formatting Helpers
    // ============================================================================

    /**
     * Format pace for display.
     * @return Pace string like "5:30 /km"
     */
    @JvmStatic
    external fun formatPace(distanceMeters: Double, durationMs: Long): String?

    /**
     * Calculate speed in km/h.
     */
    @JvmStatic
    external fun calculateSpeedKmh(distanceMeters: Double, durationMs: Long): Double

    /**
     * Format time duration for display.
     * @return Time string like "1:23:45" or "23:45"
     */
    @JvmStatic
    external fun formatDuration(durationMs: Long): String?

    /**
     * Format distance for display.
     * @return Distance string like "5.00 km" or "500 m"
     */
    @JvmStatic
    external fun formatDistance(distanceMeters: Double): String?

    /**
     * Get the human-readable name for a PB distance.
     * @return Name like "5K" or "Half Marathon"
     */
    @JvmStatic
    external fun getDistanceName(distanceMeters: Double): String?

    // ============================================================================
    // Kotlin Helper Functions
    // ============================================================================

    fun getPacingStatusEnum(lat: Double, lon: Double, elapsedMs: Long): PacingStatus {
        return PacingStatus.fromInt(getPacingStatus(lat, lon, elapsedMs))
    }

    fun isBehindBanshee(lat: Double, lon: Double, elapsedMs: Long): Boolean {
        return isBehind(lat, lon, elapsedMs) == 1
    }

    // Activity helpers with typed ActivityType

    fun createActivity(
        id: String,
        name: String,
        activityType: ActivityType,
        coordsJson: String,
        recordedAt: Long
    ): String? = createActivityJson(id, name, activityType.value, coordsJson, recordedAt)

    fun updatePersonalBests(existingPbsJson: String?, activityJson: String): String? =
        updatePbs(existingPbsJson, activityJson)

    fun getNewPersonalBests(existingPbsJson: String?, activityJson: String): String? =
        getNewPbs(existingPbsJson, activityJson)

    fun getPersonalBestsForType(pbsJson: String, activityType: ActivityType): String? =
        getPbsForType(pbsJson, activityType.value)

    fun filterActivities(indexJson: String, activityType: ActivityType?): String? =
        filterActivitiesByType(indexJson, activityType?.value ?: -1)

    fun formatPaceString(distanceMeters: Double, durationMs: Long): String =
        formatPace(distanceMeters, durationMs) ?: "0:00 /km"

    fun formatDurationString(durationMs: Long): String =
        formatDuration(durationMs) ?: "0:00"

    fun formatDistanceString(distanceMeters: Double): String =
        formatDistance(distanceMeters) ?: "0 m"

    fun getDistanceNameString(distanceMeters: Double): String =
        getDistanceName(distanceMeters) ?: "Custom"
}
