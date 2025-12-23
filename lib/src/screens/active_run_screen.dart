import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:banshee_run_app/src/screens/run_setup_screen.dart';
import 'package:banshee_run_app/src/screens/run_complete_screen.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/widgets/stats_overlay.dart';

class ActiveRunScreen extends ConsumerStatefulWidget {
  final BansheeMode bansheeMode;
  final double? targetPaceSecPerKm;
  final String? bansheeRunId;

  const ActiveRunScreen({
    super.key,
    required this.bansheeMode,
    this.targetPaceSecPerKm,
    this.bansheeRunId,
  });

  @override
  ConsumerState<ActiveRunScreen> createState() => _ActiveRunScreenState();
}

class _ActiveRunScreenState extends ConsumerState<ActiveRunScreen> {
  final MapController _mapController = MapController();

  bool _isPaused = false;

  // Run stats
  int _elapsedMs = 0;
  double _distanceM = 0.0;
  double _currentPaceSecPerKm = 0.0;
  double _bansheeDeltaM = 0.0;

  // Positions
  LatLng? _currentPosition;
  LatLng? _bansheePosition;
  List<LatLng> _route = [];

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startRun();
  }

  void _startRun() {
    // Start timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _elapsedMs += 1000;
          // TODO: Update from actual GPS
        });
      }
    });

    // TODO: Start GPS tracking
    // For demo, set a default position
    setState(() {
      _currentPosition = const LatLng(51.5074, -0.1278); // London
    });
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  void _stopRun() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('End Run?'),
        content: const Text('Are you sure you want to end this run?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finishRun();
            },
            child: const Text(
              'End Run',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _finishRun() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => RunCompleteScreen(
          distanceM: _distanceM,
          durationMs: _elapsedMs,
          avgPaceSecPerKm: _distanceM > 0
              ? (_elapsedMs / 1000) / (_distanceM / 1000)
              : 0,
          route: _route,
          bansheeDeltaM: _bansheeDeltaM,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? const LatLng(51.5074, -0.1278),
              initialZoom: 16.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bansheerun.app',
              ),
              // Route polyline
              if (_route.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _route,
                      color: AppColors.primary,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),
              // Markers
              MarkerLayer(
                markers: [
                  // Current position
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  // Banshee position
                  if (_bansheePosition != null &&
                      widget.bansheeMode != BansheeMode.none)
                    Marker(
                      point: _bansheePosition!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _bansheeDeltaM > 0
                              ? AppColors.bansheeAhead
                              : AppColors.bansheeBehind,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.directions_run,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Stats overlay at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: StatsOverlay(
                elapsedMs: _elapsedMs,
                distanceM: _distanceM,
                currentPaceSecPerKm: _currentPaceSecPerKm,
                bansheeDeltaM: widget.bansheeMode != BansheeMode.none
                    ? _bansheeDeltaM
                    : null,
                isPaused: _isPaused,
              ),
            ),
          ),

          // Controls at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.background.withValues(alpha: 0.9),
                      AppColors.background,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Stop button
                    _ControlButton(
                      icon: Icons.stop,
                      label: 'Stop',
                      color: AppColors.error,
                      onPressed: _stopRun,
                    ),
                    // Pause/Resume button
                    _ControlButton(
                      icon: _isPaused ? Icons.play_arrow : Icons.pause,
                      label: _isPaused ? 'Resume' : 'Pause',
                      color: AppColors.primary,
                      onPressed: _togglePause,
                      isLarge: true,
                    ),
                    // Center map button
                    _ControlButton(
                      icon: Icons.my_location,
                      label: 'Center',
                      color: AppColors.surfaceLight,
                      onPressed: () {
                        if (_currentPosition != null) {
                          _mapController.move(_currentPosition!, 16.0);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;
  final bool isLarge;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = isLarge ? 72.0 : 56.0;
    final iconSize = isLarge ? 32.0 : 24.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: iconSize),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
