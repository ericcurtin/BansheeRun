package com.bansheerun

import android.Manifest
import android.annotation.SuppressLint
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.location.Location
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.widget.Button
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationServices
import org.osmdroid.views.MapView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var distanceText: TextView
    private lateinit var timeText: TextView
    private lateinit var timeDiffText: TextView
    private lateinit var startStopButton: Button
    private lateinit var activitiesButton: Button
    private lateinit var pbsButton: Button
    private lateinit var activityTypeGroup: RadioGroup
    private lateinit var mapView: MapView
    private lateinit var mapController: MapController
    private lateinit var weatherOverlay: BansheeWeatherOverlay
    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var bansheeModeStatus: TextView

    private var trackingService: RunTrackingService? = null
    private var isServiceBound = false
    private var isRunning = false
    private var selectedActivityType: BansheeLib.ActivityType = BansheeLib.ActivityType.RUN

    // Banshee mode state
    private var bansheeActivityId: String? = null
    private var bansheeStartPoint: Pair<Double, Double>? = null
    private var bansheeEndPoint: Pair<Double, Double>? = null
    private var waitingForStart = false
    private var bansheeGameActive = false

    private val startProximityThreshold = 30.0 // meters
    private val endProximityThreshold = 30.0 // meters

    private lateinit var activityRepository: ActivityRepository

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as RunTrackingService.LocalBinder
            trackingService = binder.getService()
            isServiceBound = true
            trackingService?.setUpdateCallback { status, distance, timeMs, timeDiffMs, lat, lon ->
                runOnUiThread {
                    handleLocationUpdate(status, distance, timeMs, timeDiffMs, lat, lon)
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            trackingService = null
            isServiceBound = false
        }
    }

    private fun handleLocationUpdate(
        status: BansheeLib.PacingStatus,
        distance: Double,
        timeMs: Long,
        timeDiffMs: Long,
        lat: Double,
        lon: Double
    ) {
        // Handle banshee mode start point detection
        if (waitingForStart) {
            bansheeStartPoint?.let { startPoint ->
                val distanceToStart = distanceBetween(lat, lon, startPoint.first, startPoint.second)
                if (distanceToStart <= startProximityThreshold) {
                    startBansheeRace()
                    // Continue to record the first coordinate
                } else {
                    mapController.updatePosition(lat, lon, timeMs)
                    return
                }
            } ?: run {
                mapController.updatePosition(lat, lon, timeMs)
                return
            }
        }

        updateUI(status, distance, timeMs, timeDiffMs)
        mapController.updatePosition(lat, lon, timeMs)
        mapController.updateWanderingBansheePacing(status, timeDiffMs)

        // Handle banshee mode end point detection
        if (bansheeGameActive) {
            bansheeEndPoint?.let { endPoint ->
                val distanceToEnd = distanceBetween(lat, lon, endPoint.first, endPoint.second)
                if (distanceToEnd <= endProximityThreshold) {
                    finishBansheeRace()
                }
            }
        }
    }

    private fun distanceBetween(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Float {
        val results = FloatArray(1)
        Location.distanceBetween(lat1, lon1, lat2, lon2, results)
        return results[0]
    }

    private fun startBansheeRace() {
        waitingForStart = false
        bansheeGameActive = true
        trackingService?.resetStartTime()
        bansheeModeStatus.text = "Racing against banshee!"
        bansheeModeStatus.setTextColor(android.graphics.Color.GREEN)
        Toast.makeText(this, "Race started!", Toast.LENGTH_SHORT).show()
    }

    private fun finishBansheeRace() {
        bansheeGameActive = false
        Toast.makeText(this, "Race finished!", Toast.LENGTH_SHORT).show()
        stopRun()
    }

    private val initialLocationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineLocationGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        if (fineLocationGranted) {
            getInitialLocation()
        }
    }

    private val locationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        val fineLocationGranted = permissions[Manifest.permission.ACCESS_FINE_LOCATION] ?: false
        if (fineLocationGranted) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                requestNotificationPermission()
            } else {
                startRun()
            }
        } else {
            Toast.makeText(this, "Location permission required", Toast.LENGTH_SHORT).show()
        }
    }

    private val notificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            startRun()
        } else {
            Toast.makeText(this, "Notification permission required for tracking", Toast.LENGTH_SHORT).show()
        }
    }

    private val startupNotificationPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { _ ->
        // No action needed - just requesting permission at startup
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        activityRepository = ActivityRepository.getInstance(this)

        statusText = findViewById(R.id.statusText)
        distanceText = findViewById(R.id.distanceText)
        timeText = findViewById(R.id.timeText)
        timeDiffText = findViewById(R.id.timeDiffText)
        startStopButton = findViewById(R.id.startStopButton)
        activitiesButton = findViewById(R.id.activitiesButton)
        pbsButton = findViewById(R.id.pbsButton)
        activityTypeGroup = findViewById(R.id.activityTypeGroup)
        bansheeModeStatus = findViewById(R.id.bansheeModeStatus)

        mapView = findViewById(R.id.mapView)
        mapController = MapController(this, mapView)
        mapController.initialize()

        weatherOverlay = findViewById(R.id.weatherOverlay)

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        requestInitialLocation()
        requestNotificationPermissionAtStartup()

        // Activity type selection
        activityTypeGroup.setOnCheckedChangeListener { _, checkedId ->
            selectedActivityType = when (checkedId) {
                R.id.radioRun -> BansheeLib.ActivityType.RUN
                R.id.radioWalk -> BansheeLib.ActivityType.WALK
                R.id.radioCycle -> BansheeLib.ActivityType.CYCLE
                R.id.radioSkate -> BansheeLib.ActivityType.ROLLER_SKATE
                else -> BansheeLib.ActivityType.RUN
            }
            updateStartButtonText()
            // Update the wandering banshee to match the selected activity type
            mapController.setWanderingBansheeActivityType(selectedActivityType)
        }

        startStopButton.setOnClickListener {
            if (isRunning) {
                stopRun()
            } else {
                checkPermissionsAndStartRun()
            }
        }

        activitiesButton.setOnClickListener {
            startActivity(Intent(this, ActivityListActivity::class.java))
        }

        pbsButton.setOnClickListener {
            startActivity(Intent(this, PersonalBestsActivity::class.java))
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleBansheeIntent(intent)
    }

    private fun handleBansheeIntent(intent: Intent?) {
        intent?.getStringExtra("banshee_activity_id")?.let { activityId ->
            loadActivityAsBanshee(activityId)
        }
    }

    override fun onStart() {
        super.onStart()
        Intent(this, RunTrackingService::class.java).also { intent ->
            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun onResume() {
        super.onResume()
        mapController.onResume()
    }

    override fun onPause() {
        super.onPause()
        mapController.onPause()
    }

    override fun onStop() {
        super.onStop()
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        mapController.onDestroy()
    }

    private fun requestInitialLocation() {
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED -> {
                getInitialLocation()
            }
            else -> {
                initialLocationPermissionLauncher.launch(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                )
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun getInitialLocation() {
        fusedLocationClient.lastLocation.addOnSuccessListener { location ->
            location?.let {
                mapController.setInitialPosition(it.latitude, it.longitude)
            }
        }
    }

    private fun checkPermissionsAndStartRun() {
        when {
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    requestNotificationPermission()
                } else {
                    startRun()
                }
            }
            else -> {
                locationPermissionLauncher.launch(
                    arrayOf(
                        Manifest.permission.ACCESS_FINE_LOCATION,
                        Manifest.permission.ACCESS_COARSE_LOCATION
                    )
                )
            }
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) == PackageManager.PERMISSION_GRANTED
            ) {
                startRun()
            } else {
                notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun requestNotificationPermissionAtStartup() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                startupNotificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
    }

    private fun startRun() {
        mapController.resetCurrentRun()
        val intent = Intent(this, RunTrackingService::class.java)
        ContextCompat.startForegroundService(this, intent)
        trackingService?.startTracking()
        isRunning = true
        startStopButton.text = getString(R.string.stop_run)
        // Disable activity type selection while running
        for (i in 0 until activityTypeGroup.childCount) {
            activityTypeGroup.getChildAt(i).isEnabled = false
        }

        // If banshee mode, wait for start point
        if (bansheeActivityId != null) {
            waitingForStart = true
            bansheeGameActive = false
            trackingService?.pauseTracking()
            bansheeModeStatus.text = "Go to start point to begin race!"
            bansheeModeStatus.setTextColor(android.graphics.Color.parseColor("#FFA500"))
            bansheeModeStatus.visibility = android.view.View.VISIBLE
        }
    }

    private fun stopRun() {
        // Get recorded data before stopping
        val coordinates = trackingService?.getRecordedCoordinates() ?: emptyList()
        val totalDistance = trackingService?.getTotalDistance() ?: 0.0
        val durationMs = trackingService?.getElapsedMs() ?: 0L

        trackingService?.stopTracking()
        isRunning = false
        waitingForStart = false
        bansheeGameActive = false
        bansheeModeStatus.visibility = android.view.View.GONE
        updateStartButtonText()
        weatherOverlay.hide()

        // Re-enable activity type selection
        for (i in 0 until activityTypeGroup.childCount) {
            activityTypeGroup.getChildAt(i).isEnabled = true
        }

        // Save activity if we have enough data
        if (coordinates.size >= 2) {
            saveActivity(coordinates, totalDistance, durationMs)
        }

        // Clear banshee state after saving
        if (bansheeActivityId != null) {
            clearBanshee()
        }
    }

    private fun saveActivity(
        coordinates: List<RunTrackingService.RecordedCoordinate>,
        totalDistance: Double,
        durationMs: Long
    ) {
        // Build coordinates JSON
        val coordsJson = coordinates.joinToString(
            prefix = "[",
            postfix = "]",
            separator = ","
        ) { coord ->
            """{"lat":${coord.lat},"lon":${coord.lon},"timestamp_ms":${coord.timestampMs}}"""
        }

        // Generate activity ID and name
        val id = UUID.randomUUID().toString()
        val dateFormat = SimpleDateFormat("MMM d 'at' h:mm a", Locale.getDefault())
        val typeName = selectedActivityType.displayName
        val name = "$typeName - ${dateFormat.format(Date())}"
        val recordedAt = System.currentTimeMillis()

        // Create activity JSON via Rust
        val activityJson = BansheeLib.createActivityJson(
            id, name, selectedActivityType.value, coordsJson, recordedAt
        )

        if (activityJson != null) {
            // Check for new PBs before saving
            val newPBs = activityRepository.getNewPBs(activityJson)

            // Save activity
            activityRepository.saveActivity(activityJson)

            // Show PB toast if any new records
            if (newPBs.isNotEmpty()) {
                val pbMessage = newPBs.joinToString("\n") { pb ->
                    "${pb.getDistanceName()}: ${pb.getFormattedTime()}"
                }
                Toast.makeText(this, "New PB!\n$pbMessage", Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "Activity saved!", Toast.LENGTH_SHORT).show()
            }
        } else {
            Toast.makeText(this, "Failed to save activity", Toast.LENGTH_SHORT).show()
        }
    }

    private fun updateUI(
        status: BansheeLib.PacingStatus,
        distance: Double,
        timeMs: Long,
        timeDiffMs: Long
    ) {
        statusText.text = when (status) {
            BansheeLib.PacingStatus.AHEAD -> getString(R.string.status_ahead)
            BansheeLib.PacingStatus.BEHIND -> getString(R.string.status_behind)
            BansheeLib.PacingStatus.UNKNOWN -> getString(R.string.status_unknown)
        }

        distanceText.text = String.format("Distance: %.2f km", distance / 1000.0)

        val minutes = (timeMs / 1000) / 60
        val seconds = (timeMs / 1000) % 60
        timeText.text = String.format("Time: %02d:%02d", minutes, seconds)

        if (status != BansheeLib.PacingStatus.UNKNOWN) {
            val diffSeconds = kotlin.math.abs(timeDiffMs) / 1000
            val sign = if (timeDiffMs >= 0) "+" else "-"
            timeDiffText.text = String.format("%s%d seconds", sign, diffSeconds)
        } else {
            timeDiffText.text = ""
        }

        // Show banshee weather effects when falling behind
        when (status) {
            BansheeLib.PacingStatus.BEHIND -> {
                // Intensity increases based on how far behind (more seconds behind = stronger effect)
                val intensity = (kotlin.math.abs(timeDiffMs) / 30000f).coerceIn(0.3f, 1f)
                weatherOverlay.setIntensity(intensity)
            }
            else -> weatherOverlay.hide()
        }
    }

    fun loadActivityAsBanshee(activityId: String) {
        val activityJson = activityRepository.loadActivity(activityId)
        if (activityJson == null) {
            Toast.makeText(this, "Failed to load activity", Toast.LENGTH_SHORT).show()
            return
        }

        // Parse activity to get start/end points
        try {
            val jsonObject = org.json.JSONObject(activityJson)
            val coordinates = jsonObject.getJSONArray("coordinates")
            if (coordinates.length() >= 2) {
                val firstCoord = coordinates.getJSONObject(0)
                val lastCoord = coordinates.getJSONObject(coordinates.length() - 1)

                bansheeStartPoint = Pair(firstCoord.getDouble("lat"), firstCoord.getDouble("lon"))
                bansheeEndPoint = Pair(lastCoord.getDouble("lat"), lastCoord.getDouble("lon"))
            }
        } catch (e: Exception) {
            Toast.makeText(this, "Failed to parse activity coordinates", Toast.LENGTH_SHORT).show()
            return
        }

        val result = BansheeLib.initSession(activityJson)
        if (result == 0) {
            bansheeActivityId = activityId
            Toast.makeText(this, "Banshee loaded! Press Start to begin.", Toast.LENGTH_SHORT).show()
            mapController.loadBansheeRoute()
        } else {
            Toast.makeText(this, "Failed to load banshee", Toast.LENGTH_SHORT).show()
            bansheeStartPoint = null
            bansheeEndPoint = null
        }
    }

    fun clearBanshee() {
        BansheeLib.clearSession()
        bansheeActivityId = null
        bansheeStartPoint = null
        bansheeEndPoint = null
        waitingForStart = false
        bansheeGameActive = false
        bansheeModeStatus.visibility = android.view.View.GONE
    }

    private fun updateStartButtonText() {
        if (!isRunning) {
            startStopButton.text = when (selectedActivityType) {
                BansheeLib.ActivityType.RUN -> getString(R.string.start_run)
                BansheeLib.ActivityType.WALK -> getString(R.string.start_walk)
                BansheeLib.ActivityType.CYCLE -> getString(R.string.start_cycle)
                BansheeLib.ActivityType.ROLLER_SKATE -> getString(R.string.start_skate)
            }
        }
    }
}
