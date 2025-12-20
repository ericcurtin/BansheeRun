package com.bansheerun

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import android.widget.Button
import android.widget.TextView
import android.widget.Toast
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat

class MainActivity : AppCompatActivity() {

    private lateinit var statusText: TextView
    private lateinit var distanceText: TextView
    private lateinit var timeText: TextView
    private lateinit var timeDiffText: TextView
    private lateinit var startStopButton: Button
    private lateinit var selectBestRunButton: Button

    private var trackingService: RunTrackingService? = null
    private var isServiceBound = false
    private var isRunning = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            val binder = service as RunTrackingService.LocalBinder
            trackingService = binder.getService()
            isServiceBound = true
            trackingService?.setUpdateCallback { status, distance, timeMs, timeDiffMs ->
                runOnUiThread {
                    updateUI(status, distance, timeMs, timeDiffMs)
                }
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            trackingService = null
            isServiceBound = false
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

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        statusText = findViewById(R.id.statusText)
        distanceText = findViewById(R.id.distanceText)
        timeText = findViewById(R.id.timeText)
        timeDiffText = findViewById(R.id.timeDiffText)
        startStopButton = findViewById(R.id.startStopButton)
        selectBestRunButton = findViewById(R.id.selectBestRunButton)

        startStopButton.setOnClickListener {
            if (isRunning) {
                stopRun()
            } else {
                checkPermissionsAndStartRun()
            }
        }

        selectBestRunButton.setOnClickListener {
            // Load a sample best run for demo purposes
            loadSampleBestRun()
        }
    }

    override fun onStart() {
        super.onStart()
        Intent(this, RunTrackingService::class.java).also { intent ->
            bindService(intent, serviceConnection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun onStop() {
        super.onStop()
        if (isServiceBound) {
            unbindService(serviceConnection)
            isServiceBound = false
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

    private fun startRun() {
        val intent = Intent(this, RunTrackingService::class.java)
        ContextCompat.startForegroundService(this, intent)
        trackingService?.startTracking()
        isRunning = true
        startStopButton.text = getString(R.string.stop_run)
    }

    private fun stopRun() {
        trackingService?.stopTracking()
        isRunning = false
        startStopButton.text = getString(R.string.start_run)
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
    }

    private fun loadSampleBestRun() {
        // Sample run record JSON for testing
        val sampleJson = """
        {
            "id": "sample-run-1",
            "name": "Sample 5K",
            "coordinates": [
                {"lat": 40.7128, "lon": -74.0060, "timestamp_ms": 0},
                {"lat": 40.7135, "lon": -74.0055, "timestamp_ms": 60000},
                {"lat": 40.7142, "lon": -74.0050, "timestamp_ms": 120000},
                {"lat": 40.7149, "lon": -74.0045, "timestamp_ms": 180000},
                {"lat": 40.7156, "lon": -74.0040, "timestamp_ms": 240000}
            ],
            "total_distance_meters": 500.0,
            "duration_ms": 240000,
            "recorded_at": 1700000000000
        }
        """.trimIndent()

        val result = BansheeLib.initSession(sampleJson)
        if (result == 0) {
            Toast.makeText(this, "Best run loaded!", Toast.LENGTH_SHORT).show()
        } else {
            Toast.makeText(this, "Failed to load best run", Toast.LENGTH_SHORT).show()
        }
    }
}
