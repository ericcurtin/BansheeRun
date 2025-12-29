import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:latlong2/latlong.dart';
import 'package:banshee_run_app/src/providers/run_provider.dart';
import 'package:banshee_run_app/src/screens/run_setup_screen.dart';
import 'package:banshee_run_app/src/screens/run_complete_screen.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/widgets/stats_overlay.dart';
import 'package:banshee_run_app/src/services/tile_cache_service.dart';

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

  // Banshee tracking (not part of foreground service)
  LatLng? _bansheePosition;
  double _bansheeDeltaM = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(foregroundRunProvider.notifier).startRun();
    });
  }

  void _togglePause() {
    final notifier = ref.read(foregroundRunProvider.notifier);
    final state = ref.read(foregroundRunProvider);

    if (state.status == ForegroundRunStatus.paused) {
      notifier.resumeRun();
    } else {
      notifier.pauseRun();
    }
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

  Future<void> _finishRun() async {
    final finalState = await ref
        .read(foregroundRunProvider.notifier)
        .finishRun();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => RunCompleteScreen(
            distanceM: finalState.distanceM,
            durationMs: finalState.elapsedMs,
            avgPaceSecPerKm: finalState.distanceM > 0
                ? (finalState.elapsedMs / 1000) / (finalState.distanceM / 1000)
                : 0,
            route: finalState.route,
            startTimeMs: finalState.startTimeMs,
            bansheeDeltaM: _bansheeDeltaM,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runState = ref.watch(foregroundRunProvider);
    final currentPosition = runState.currentPosition;
    final route = runState.route;
    final isPaused = runState.status == ForegroundRunStatus.paused;

    // Center map when position updates
    if (currentPosition != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _mapController.move(currentPosition, _mapController.camera.zoom);
        } catch (_) {
          // Map not ready yet
        }
      });
    }

    return WithForegroundTask(
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter:
                    currentPosition ?? const LatLng(51.5074, -0.1278),
                initialZoom: 16.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.bansheerun.app',
                  tileProvider: TileCacheService.instance.getTileProvider(),
                ),
                // Route polyline
                if (route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route,
                        color: AppColors.primary,
                        strokeWidth: 4.0,
                      ),
                    ],
                  ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Current position
                    if (currentPosition != null)
                      Marker(
                        point: currentPosition,
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
                  elapsedMs: runState.elapsedMs,
                  distanceM: runState.distanceM,
                  currentPaceSecPerKm: runState.currentPaceSecPerKm ?? 0,
                  bansheeDeltaM: widget.bansheeMode != BansheeMode.none
                      ? _bansheeDeltaM
                      : null,
                  isPaused: isPaused,
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
                        icon: isPaused ? Icons.play_arrow : Icons.pause,
                        label: isPaused ? 'Resume' : 'Pause',
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
                          if (currentPosition != null) {
                            _mapController.move(currentPosition, 16.0);
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
