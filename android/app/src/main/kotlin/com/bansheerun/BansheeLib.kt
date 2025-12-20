package com.bansheerun

/**
 * JNI wrapper for the BansheeRun Rust library.
 */
object BansheeLib {
    init {
        System.loadLibrary("banshee_run")
    }

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

    // Kotlin helper functions

    fun getPacingStatusEnum(lat: Double, lon: Double, elapsedMs: Long): PacingStatus {
        return PacingStatus.fromInt(getPacingStatus(lat, lon, elapsedMs))
    }

    fun isBehindBanshee(lat: Double, lon: Double, elapsedMs: Long): Boolean {
        return isBehind(lat, lon, elapsedMs) == 1
    }
}
