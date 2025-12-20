package com.bansheerun

import android.content.Context
import android.graphics.Color
import androidx.core.content.ContextCompat
import org.osmdroid.config.Configuration
import org.osmdroid.tileprovider.tilesource.TileSourceFactory
import org.osmdroid.util.GeoPoint
import org.osmdroid.views.MapView
import org.osmdroid.views.overlay.Marker
import org.osmdroid.views.overlay.Polyline

class MapController(
    private val context: Context,
    private val mapView: MapView
) {
    private var runnerMarker: Marker? = null
    private var bansheeMarker: Marker? = null

    private val currentRunPolyline: Polyline = Polyline().apply {
        outlinePaint.color = Color.BLUE
        outlinePaint.strokeWidth = 8f
    }

    private val bansheeRoutePolyline: Polyline = Polyline().apply {
        outlinePaint.color = Color.RED
        outlinePaint.strokeWidth = 6f
        outlinePaint.alpha = 150
    }

    private val currentRunPoints = mutableListOf<GeoPoint>()
    private var lastAddedPoint: GeoPoint? = null

    companion object {
        private const val MIN_POINT_DISTANCE_METERS = 5.0
        private const val DEFAULT_ZOOM = 18.0
    }

    fun initialize() {
        Configuration.getInstance().load(
            context,
            context.getSharedPreferences("osmdroid", Context.MODE_PRIVATE)
        )
        Configuration.getInstance().userAgentValue = context.packageName

        mapView.setTileSource(TileSourceFactory.MAPNIK)
        mapView.setMultiTouchControls(true)
        mapView.controller.setZoom(DEFAULT_ZOOM)

        mapView.overlays.add(bansheeRoutePolyline)
        mapView.overlays.add(currentRunPolyline)

        runnerMarker = Marker(mapView).apply {
            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            title = "You"
            icon = ContextCompat.getDrawable(context, R.drawable.ic_runner_marker)
        }

        bansheeMarker = Marker(mapView).apply {
            setAnchor(Marker.ANCHOR_CENTER, Marker.ANCHOR_BOTTOM)
            title = "Banshee"
            icon = ContextCompat.getDrawable(context, R.drawable.ic_banshee_marker)
        }

        mapView.overlays.add(runnerMarker)
        mapView.overlays.add(bansheeMarker)
    }

    fun loadBansheeRoute() {
        val coords = BansheeLib.getBestRunCoordinates()
        if (coords.isEmpty()) return

        val points = mutableListOf<GeoPoint>()
        for (i in coords.indices step 2) {
            if (i + 1 < coords.size) {
                points.add(GeoPoint(coords[i], coords[i + 1]))
            }
        }

        bansheeRoutePolyline.setPoints(points)

        if (points.isNotEmpty()) {
            mapView.controller.setCenter(points[0])
        }

        mapView.invalidate()
    }

    fun clearBansheeRoute() {
        bansheeRoutePolyline.setPoints(emptyList())
        bansheeMarker?.position = null
        mapView.invalidate()
    }

    fun resetCurrentRun() {
        currentRunPoints.clear()
        currentRunPolyline.setPoints(emptyList())
        lastAddedPoint = null
        mapView.invalidate()
    }

    fun updatePosition(lat: Double, lon: Double, elapsedMs: Long) {
        val currentPoint = GeoPoint(lat, lon)

        runnerMarker?.position = currentPoint

        val shouldAddPoint = lastAddedPoint?.let { last ->
            currentPoint.distanceToAsDouble(last) >= MIN_POINT_DISTANCE_METERS
        } ?: true

        if (shouldAddPoint) {
            currentRunPoints.add(currentPoint)
            currentRunPolyline.setPoints(currentRunPoints)
            lastAddedPoint = currentPoint
        }

        val bansheeCoords = BansheeLib.getBansheePositionAtTime(elapsedMs)
        if (bansheeCoords.size >= 2) {
            bansheeMarker?.position = GeoPoint(bansheeCoords[0], bansheeCoords[1])
        }

        mapView.controller.animateTo(currentPoint)
        mapView.invalidate()
    }

    fun onResume() {
        mapView.onResume()
    }

    fun onPause() {
        mapView.onPause()
    }
}
