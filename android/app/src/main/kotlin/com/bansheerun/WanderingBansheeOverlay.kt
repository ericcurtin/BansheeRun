package com.bansheerun

import android.content.Context
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Overlay
import kotlin.math.cos
import kotlin.math.sin

/**
 * A wandering banshee that orbits around the map edges.
 * She gets closer when you fall behind and further away when you're ahead,
 * but is always visible on the map.
 */
class WanderingBansheeOverlay(
    private val context: Context,
    private val mapView: MapView
) : Overlay() {

    private var bansheeDrawable: Drawable? = null
    private var currentActivityType: BansheeLib.ActivityType = BansheeLib.ActivityType.RUN
    private var currentPosition: GeoPoint? = null
    private var centerPosition: GeoPoint? = null

    // Orbital parameters
    private var orbitAngle = 0.0  // Current angle in radians
    private var targetOrbitRadius = 0.7  // 0.0 = center, 1.0 = edge of visible map
    private var currentOrbitRadius = 0.7
    private var wanderOffset = 0.0  // Additional wandering perturbation

    // Animation
    private val handler = Handler(Looper.getMainLooper())
    private var isAnimating = false
    private val updateIntervalMs = 50L  // 20 FPS

    // Movement speeds
    private val orbitSpeed = 0.015  // Radians per update (slow circular movement)
    private val wanderSpeed = 0.03  // Speed of wandering perturbation
    private val radiusLerpSpeed = 0.05  // How fast radius adjusts

    // Visibility state
    private var isVisible = true

    companion object {
        // Pacing-based radius mapping
        // When ahead: banshee stays at edges (radius = 0.85-0.95)
        // When behind: banshee comes closer (radius = 0.3-0.6)
        private const val MIN_RADIUS_BEHIND = 0.25  // Very close when very behind
        private const val MAX_RADIUS_BEHIND = 0.5   // Moderately close when slightly behind
        private const val MIN_RADIUS_AHEAD = 0.7    // Still visible when ahead
        private const val MAX_RADIUS_AHEAD = 0.9    // Far edge when very ahead
        private const val NEUTRAL_RADIUS = 0.65     // When no banshee loaded / unknown

        // Max time difference to consider for scaling (30 seconds)
        private const val MAX_TIME_DIFF_MS = 30000L
    }

    init {
        updateBansheeDrawable()
    }

    /**
     * Update the banshee drawable based on the current activity type
     */
    private fun updateBansheeDrawable() {
        val drawableRes = when (currentActivityType) {
            BansheeLib.ActivityType.RUN -> R.drawable.ic_banshee_run
            BansheeLib.ActivityType.WALK -> R.drawable.ic_banshee_walk
            BansheeLib.ActivityType.CYCLE -> R.drawable.ic_banshee_cycle
            BansheeLib.ActivityType.ROLLER_SKATE -> R.drawable.ic_banshee_skate
        }
        bansheeDrawable = ContextCompat.getDrawable(context, drawableRes)
    }

    /**
     * Set the activity type, which changes the banshee appearance
     */
    fun setActivityType(activityType: BansheeLib.ActivityType) {
        if (currentActivityType != activityType) {
            currentActivityType = activityType
            updateBansheeDrawable()
            mapView.invalidate()
        }
    }

    private val animationRunnable = object : Runnable {
        override fun run() {
            if (!isAnimating) return

            updatePosition()
            mapView.invalidate()

            handler.postDelayed(this, updateIntervalMs)
        }
    }

    /**
     * Start the wandering animation
     */
    fun startWandering() {
        if (isAnimating) return
        isAnimating = true
        handler.post(animationRunnable)
    }

    /**
     * Stop the wandering animation
     */
    fun stopWandering() {
        isAnimating = false
        handler.removeCallbacks(animationRunnable)
    }

    /**
     * Set visibility of the wandering banshee
     */
    fun setWanderingVisible(visible: Boolean) {
        isVisible = visible
        if (visible && !isAnimating) {
            startWandering()
        }
        mapView.invalidate()
    }

    /**
     * Update the center point the banshee orbits around (usually the runner's position)
     */
    fun setCenter(center: GeoPoint) {
        centerPosition = center
    }

    /**
     * Update banshee behavior based on pacing status
     * @param status The current pacing status (AHEAD, BEHIND, UNKNOWN)
     * @param timeDiffMs Time difference in milliseconds (positive = ahead, negative = behind)
     */
    fun updatePacingStatus(status: BansheeLib.PacingStatus, timeDiffMs: Long) {
        targetOrbitRadius = when (status) {
            BansheeLib.PacingStatus.BEHIND -> {
                // The more behind, the closer the banshee comes
                val behindFactor = (kotlin.math.abs(timeDiffMs).toDouble() / MAX_TIME_DIFF_MS)
                    .coerceIn(0.0, 1.0)
                // Interpolate: more behind = smaller radius (closer)
                MAX_RADIUS_BEHIND - (behindFactor * (MAX_RADIUS_BEHIND - MIN_RADIUS_BEHIND))
            }
            BansheeLib.PacingStatus.AHEAD -> {
                // The more ahead, the further the banshee goes
                val aheadFactor = (timeDiffMs.toDouble() / MAX_TIME_DIFF_MS)
                    .coerceIn(0.0, 1.0)
                // Interpolate: more ahead = larger radius (further)
                MIN_RADIUS_AHEAD + (aheadFactor * (MAX_RADIUS_AHEAD - MIN_RADIUS_AHEAD))
            }
            BansheeLib.PacingStatus.UNKNOWN -> NEUTRAL_RADIUS
        }
    }

    private fun updatePosition() {
        val center = centerPosition ?: return

        // Update orbit angle (constant circular movement)
        orbitAngle += orbitSpeed
        if (orbitAngle > 2 * Math.PI) {
            orbitAngle -= 2 * Math.PI
        }

        // Add wandering perturbation for more organic movement
        wanderOffset += wanderSpeed
        val wanderX = sin(wanderOffset * 1.3) * 0.1
        val wanderY = cos(wanderOffset * 0.7) * 0.1

        // Smoothly interpolate radius toward target
        currentOrbitRadius += (targetOrbitRadius - currentOrbitRadius) * radiusLerpSpeed

        // Calculate the visible map extent
        val mapBounds = mapView.boundingBox
        val latSpan = mapBounds.latitudeSpan / 2.0
        val lonSpan = mapBounds.longitudeSpan / 2.0

        // Calculate banshee position on the orbit
        val effectiveRadius = currentOrbitRadius + wanderX * 0.2
        val offsetLat = sin(orbitAngle + wanderY) * latSpan * effectiveRadius
        val offsetLon = cos(orbitAngle + wanderX) * lonSpan * effectiveRadius

        currentPosition = GeoPoint(
            center.latitude + offsetLat,
            center.longitude + offsetLon
        )
    }

    override fun draw(canvas: Canvas, mapView: MapView, shadow: Boolean) {
        if (shadow) return
        if (!isVisible) return

        val position = currentPosition ?: return
        val drawable = bansheeDrawable ?: return

        // Convert geo position to screen coordinates
        val screenPoint = mapView.projection.toPixels(position, null)

        // Draw the banshee
        val halfWidth = drawable.intrinsicWidth / 2
        val halfHeight = drawable.intrinsicHeight / 2

        drawable.setBounds(
            screenPoint.x - halfWidth,
            screenPoint.y - halfHeight,
            screenPoint.x + halfWidth,
            screenPoint.y + halfHeight
        )

        // Apply slight alpha pulsing for ethereal effect
        val pulseFactor = (sin(wanderOffset * 2) * 0.15 + 0.85).toFloat()
        drawable.alpha = (255 * pulseFactor).toInt()

        drawable.draw(canvas)
    }

    override fun onPause() {
        super.onPause()
        stopWandering()
    }

    override fun onResume() {
        super.onResume()
        if (isVisible) {
            startWandering()
        }
    }

    fun onDestroy() {
        stopWandering()
        handler.removeCallbacksAndMessages(null)
    }
}
