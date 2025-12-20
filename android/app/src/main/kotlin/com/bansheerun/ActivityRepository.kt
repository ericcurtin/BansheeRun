package com.bansheerun

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Repository for storing and loading activities and personal bests.
 */
class ActivityRepository(private val context: Context) {

    private val json = Json { ignoreUnknownKeys = true }

    private val baseDir: File
        get() {
            val dir = File(context.filesDir, "banshee_run")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    private val activitiesDir: File
        get() {
            val dir = File(baseDir, "activities")
            if (!dir.exists()) dir.mkdirs()
            return dir
        }

    private val indexFile: File
        get() = File(activitiesDir, "index.json")

    private val personalBestsFile: File
        get() = File(baseDir, "personal_bests.json")

    // ============================================================================
    // Activity Index
    // ============================================================================

    fun loadActivityIndex(): ActivityIndex {
        return try {
            if (indexFile.exists()) {
                json.decodeFromString(indexFile.readText())
            } else {
                ActivityIndex(emptyList())
            }
        } catch (_: Exception) {
            ActivityIndex(emptyList())
        }
    }

    private fun saveActivityIndex(index: ActivityIndex) {
        indexFile.writeText(json.encodeToString(index))
    }

    // ============================================================================
    // Activities
    // ============================================================================

    fun saveActivity(activityJson: String) {
        // Parse activity to get ID
        val activity = try {
            json.decodeFromString<Activity>(activityJson)
        } catch (_: Exception) {
            return
        }

        // Save full activity to file
        val activityFile = File(activitiesDir, "${activity.id}.json")
        activityFile.writeText(activityJson)

        // Get summary and add to index
        val summaryJson = BansheeLib.getActivitySummary(activityJson) ?: return
        val summary = try {
            json.decodeFromString<ActivitySummary>(summaryJson)
        } catch (_: Exception) {
            return
        }

        // Update index
        val index = loadActivityIndex()
        val newActivities = listOf(summary) + index.activities
        saveActivityIndex(ActivityIndex(newActivities))

        // Update PBs
        val existingPbs = loadPersonalBestsJson()
        val updatedPbs = BansheeLib.updatePbs(existingPbs, activityJson)
        if (updatedPbs != null) {
            savePersonalBestsJson(updatedPbs)
        }
    }

    fun loadActivity(id: String): String? {
        val activityFile = File(activitiesDir, "$id.json")
        return if (activityFile.exists()) activityFile.readText() else null
    }

    fun deleteActivity(id: String) {
        // Remove from index
        val index = loadActivityIndex()
        val newActivities = index.activities.filter { it.id != id }
        saveActivityIndex(ActivityIndex(newActivities))

        // Delete file
        val activityFile = File(activitiesDir, "$id.json")
        if (activityFile.exists()) activityFile.delete()
    }

    // ============================================================================
    // Personal Bests
    // ============================================================================

    fun loadPersonalBestsJson(): String? {
        return if (personalBestsFile.exists()) {
            personalBestsFile.readText()
        } else {
            null
        }
    }

    private fun savePersonalBestsJson(pbsJson: String) {
        personalBestsFile.writeText(pbsJson)
    }

    fun loadPersonalBests(): List<PersonalBest> {
        val pbsJson = loadPersonalBestsJson() ?: return emptyList()
        return try {
            val pbs = json.decodeFromString<PersonalBestsWrapper>(pbsJson)
            pbs.records
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun getPersonalBestsForType(activityType: BansheeLib.ActivityType): List<PersonalBest> {
        val pbsJson = loadPersonalBestsJson() ?: return emptyList()
        val filteredJson = BansheeLib.getPbsForType(pbsJson, activityType.value) ?: return emptyList()
        return try {
            json.decodeFromString(filteredJson)
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun getNewPBs(activityJson: String): List<PersonalBest> {
        val existingPbs = loadPersonalBestsJson()
        val newPbsJson = BansheeLib.getNewPbs(existingPbs, activityJson) ?: return emptyList()
        return try {
            json.decodeFromString(newPbsJson)
        } catch (_: Exception) {
            emptyList()
        }
    }

    // ============================================================================
    // Filtering
    // ============================================================================

    fun getActivities(activityType: BansheeLib.ActivityType? = null): List<ActivitySummary> {
        val index = loadActivityIndex()
        return if (activityType != null) {
            index.activities.filter { it.activityType == activityType.name.lowercase() }
        } else {
            index.activities
        }
    }

    companion object {
        @Volatile
        private var instance: ActivityRepository? = null

        fun getInstance(context: Context): ActivityRepository {
            return instance ?: synchronized(this) {
                instance ?: ActivityRepository(context.applicationContext).also {
                    instance = it
                }
            }
        }
    }
}

// ============================================================================
// Data Classes
// ============================================================================

@Serializable
data class ActivityIndex(
    val activities: List<ActivitySummary>
)

@Serializable
data class ActivitySummary(
    val id: String,
    val name: String,
    val activity_type: String,
    val total_distance_meters: Double,
    val duration_ms: Long,
    val recorded_at: Long,
    val pace_min_per_km: Double
) {
    val activityType: String get() = activity_type
    val totalDistanceMeters: Double get() = total_distance_meters
    val durationMs: Long get() = duration_ms
    val recordedAt: Long get() = recorded_at
    val paceMinPerKm: Double get() = pace_min_per_km

    fun getActivityTypeEnum(): BansheeLib.ActivityType? {
        return BansheeLib.ActivityType.entries.find { it.name.lowercase() == activity_type }
    }
}

@Serializable
data class Activity(
    val id: String,
    val name: String,
    val activity_type: String,
    val coordinates: List<Coordinate>,
    val total_distance_meters: Double,
    val duration_ms: Long,
    val recorded_at: Long
)

@Serializable
data class Coordinate(
    val lat: Double,
    val lon: Double,
    val timestamp_ms: Long
)

@Serializable
data class PersonalBestsWrapper(
    val records: List<PersonalBest>
)

@Serializable
data class PersonalBest(
    val activity_type: String,
    val distance_meters: Double,
    val time_ms: Long,
    val activity_id: String,
    val achieved_at: Long,
    val pace_min_per_km: Double
) {
    val activityType: String get() = activity_type
    val distanceMeters: Double get() = distance_meters
    val timeMs: Long get() = time_ms
    val activityId: String get() = activity_id
    val achievedAt: Long get() = achieved_at
    val paceMinPerKm: Double get() = pace_min_per_km

    fun getDistanceName(): String = BansheeLib.getDistanceName(distance_meters) ?: "Custom"
    fun getFormattedTime(): String = BansheeLib.formatDuration(time_ms) ?: "0:00"
    fun getFormattedPace(): String = BansheeLib.formatPace(distance_meters, time_ms) ?: "0:00 /km"
}
