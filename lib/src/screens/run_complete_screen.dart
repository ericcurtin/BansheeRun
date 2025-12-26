import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:banshee_run_app/src/screens/home_screen.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';
import 'package:banshee_run_app/src/rust/api/run_api.dart' as rust_api;
import 'package:banshee_run_app/src/services/tile_cache_service.dart';

class RunCompleteScreen extends ConsumerStatefulWidget {
  final double distanceM;
  final int durationMs;
  final double avgPaceSecPerKm;
  final List<LatLng> route;
  final double? bansheeDeltaM;
  final int startTimeMs;

  const RunCompleteScreen({
    super.key,
    required this.distanceM,
    required this.durationMs,
    required this.avgPaceSecPerKm,
    required this.route,
    required this.startTimeMs,
    this.bansheeDeltaM,
  });

  @override
  ConsumerState<RunCompleteScreen> createState() => _RunCompleteScreenState();
}

class _RunCompleteScreenState extends ConsumerState<RunCompleteScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _saveRun() async {
    setState(() => _isSaving = true);

    try {
      // Create a new run to get a unique ID
      final runId = await rust_api.createRun();

      // Convert route points to GPS point DTOs
      // Since we don't have timestamps for each point, we'll distribute them
      // evenly across the run duration
      final points = <rust_api.GpsPointDto>[];
      if (widget.route.isNotEmpty) {
        final intervalMs = widget.route.length > 1
            ? widget.durationMs ~/ (widget.route.length - 1)
            : 0;

        for (int i = 0; i < widget.route.length; i++) {
          final point = widget.route[i];
          points.add(
            rust_api.GpsPointDto(
              lat: point.latitude,
              lon: point.longitude,
              timestampMs: widget.startTimeMs + (i * intervalMs),
            ),
          );
        }
      }

      // Create and save the run DTO
      final runDto = rust_api.RunDto(
        id: runId,
        name: _nameController.text.isNotEmpty ? _nameController.text : null,
        startTimeMs: widget.startTimeMs,
        endTimeMs: widget.startTimeMs + widget.durationMs,
        points: points,
        distanceMeters: widget.distanceM,
        durationMs: widget.durationMs,
        avgPaceSecPerKm: widget.distanceM > 0 ? widget.avgPaceSecPerKm : null,
      );

      await rust_api.saveRun(runDto: runDto);

      if (mounted) {
        _navigateHome();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save run: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _discardRun() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Discard Run?'),
        content: const Text('This run will not be saved. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateHome();
            },
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRoute = widget.route.isNotEmpty;
    final center = hasRoute
        ? LatLng(
            widget.route.map((p) => p.latitude).reduce((a, b) => a + b) /
                widget.route.length,
            widget.route.map((p) => p.longitude).reduce((a, b) => a + b) /
                widget.route.length,
          )
        : const LatLng(51.5074, -0.1278);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Run Complete'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _discardRun,
            child: const Text(
              'Discard',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Celebration header
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingLarge),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.emoji_events,
                      size: 48,
                      color: Colors.white,
                    ),
                    if (widget.bansheeDeltaM != null &&
                        widget.bansheeDeltaM! < 0)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppSizes.paddingSmall,
                        ),
                        child: Text(
                          'You beat your banshee by ${Formatters.formatDistanceKm(widget.bansheeDeltaM!.abs())}!',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Distance',
                      value: Formatters.formatDistanceKm(widget.distanceM),
                      icon: Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: _StatBox(
                      label: 'Duration',
                      value: Formatters.formatDuration(widget.durationMs),
                      icon: Icons.timer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingSmall),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Avg Pace',
                      value:
                          '${Formatters.formatPace(widget.avgPaceSecPerKm)}/km',
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: _StatBox(
                      label: 'Calories',
                      value: '~${(widget.distanceM / 1000 * 70).round()} kcal',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Map preview
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 14.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.bansheerun.app',
                      tileProvider: TileCacheService.instance.getTileProvider(),
                    ),
                    if (hasRoute)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: widget.route,
                            color: AppColors.primary,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Run name input
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Run Name (optional)',
                  hintText: 'e.g., Morning Run',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Save button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveRun,
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Run',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: AppSizes.paddingSmall),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
