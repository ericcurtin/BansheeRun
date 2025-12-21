package com.bansheerun

import android.content.Intent
import android.os.Bundle
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ActivityDetailActivity : AppCompatActivity() {

    private lateinit var activityRepository: ActivityRepository
    private var activityId: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_detail)

        supportActionBar?.title = "Activity"
        supportActionBar?.setDisplayHomeAsUpEnabled(true)

        activityRepository = ActivityRepository.getInstance(this)
        activityId = intent.getStringExtra("activity_id")

        if (activityId == null) {
            Toast.makeText(this, "Activity not found", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        loadActivityDetails()

        findViewById<Button>(R.id.bansheeModeButton).setOnClickListener {
            startBansheeMode()
        }
    }

    override fun onSupportNavigateUp(): Boolean {
        finish()
        return true
    }

    private fun loadActivityDetails() {
        val activityJson = activityRepository.loadActivity(activityId!!)
        if (activityJson == null) {
            Toast.makeText(this, "Failed to load activity", Toast.LENGTH_SHORT).show()
            finish()
            return
        }

        try {
            val jsonObject = JSONObject(activityJson)
            val name = jsonObject.getString("name")
            val activityType = jsonObject.getString("activity_type")
            val totalDistanceMeters = jsonObject.getDouble("total_distance_meters")
            val durationMs = jsonObject.getLong("duration_ms")
            val recordedAt = jsonObject.getLong("recorded_at")
            val coordinates = jsonObject.getJSONArray("coordinates")

            // Set header
            findViewById<TextView>(R.id.activityTypeIcon).text = when (activityType) {
                "run" -> "\uD83C\uDFC3"
                "walk" -> "\uD83D\uDEB6"
                "cycle" -> "\uD83D\uDEB4"
                "roller_skate" -> "\u26F8\uFE0F"
                else -> "\uD83C\uDFC3"
            }
            findViewById<TextView>(R.id.activityName).text = name
            findViewById<TextView>(R.id.activityDate).text = formatDate(recordedAt)

            // Set stats
            findViewById<TextView>(R.id.distanceValue).text =
                BansheeLib.formatDistance(totalDistanceMeters) ?: String.format("%.2f km", totalDistanceMeters / 1000.0)
            findViewById<TextView>(R.id.durationValue).text =
                BansheeLib.formatDuration(durationMs) ?: formatDuration(durationMs)
            findViewById<TextView>(R.id.paceValue).text =
                BansheeLib.formatPace(totalDistanceMeters, durationMs) ?: formatPace(totalDistanceMeters, durationMs)
            findViewById<TextView>(R.id.pointsValue).text = coordinates.length().toString()

            // Set activity details
            findViewById<TextView>(R.id.activityType).text = "Type: ${activityType.replaceFirstChar { it.uppercase() }}"

            if (coordinates.length() > 0) {
                val firstCoord = coordinates.getJSONObject(0)
                findViewById<TextView>(R.id.startPoint).text =
                    String.format("Start: %.5f, %.5f", firstCoord.getDouble("lat"), firstCoord.getDouble("lon"))

                val lastCoord = coordinates.getJSONObject(coordinates.length() - 1)
                findViewById<TextView>(R.id.endPoint).text =
                    String.format("End: %.5f, %.5f", lastCoord.getDouble("lat"), lastCoord.getDouble("lon"))
            }

        } catch (e: Exception) {
            Toast.makeText(this, "Failed to parse activity", Toast.LENGTH_SHORT).show()
            finish()
        }
    }

    private fun startBansheeMode() {
        val intent = Intent(this, MainActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        intent.putExtra("banshee_activity_id", activityId)
        startActivity(intent)
        finish()
    }

    private fun formatDate(epochMs: Long): String {
        val date = Date(epochMs)
        val formatter = SimpleDateFormat("MMMM d, yyyy 'at' h:mm a", Locale.getDefault())
        return formatter.format(date)
    }

    private fun formatDuration(ms: Long): String {
        val totalSeconds = ms / 1000
        val hours = totalSeconds / 3600
        val minutes = (totalSeconds % 3600) / 60
        val seconds = totalSeconds % 60
        return if (hours > 0) {
            String.format("%d:%02d:%02d", hours, minutes, seconds)
        } else {
            String.format("%d:%02d", minutes, seconds)
        }
    }

    private fun formatPace(distanceMeters: Double, durationMs: Long): String {
        if (distanceMeters <= 0) return "--:-- /km"
        val paceMs = (durationMs / (distanceMeters / 1000.0)).toLong()
        val paceMinutes = paceMs / 60000
        val paceSeconds = (paceMs % 60000) / 1000
        return String.format("%d:%02d /km", paceMinutes, paceSeconds)
    }
}
