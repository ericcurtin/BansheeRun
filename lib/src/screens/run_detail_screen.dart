import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';
import 'package:banshee_run_app/src/rust/api/run_api.dart' as rust_api;
import 'package:banshee_run_app/src/services/tile_cache_service.dart';
import 'package:banshee_run_app/src/screens/history_screen.dart';

class RunDetailScreen extends ConsumerStatefulWidget {
  final String runId;

  const RunDetailScreen({super.key, required this.runId});

  @override
  ConsumerState<RunDetailScreen> createState() => _RunDetailScreenState();
}

class _RunDetailScreenState extends ConsumerState<RunDetailScreen> {
  rust_api.RunDetailDto? _run;
  bool _isLoading = true;
  String? _error;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadRun();
  }

  Future<void> _loadRun() async {
    try {
      final run = await rust_api.getRun(id: widget.runId);
      if (mounted) {
        setState(() {
          _run = run;
          _isLoading = false;
          if (run == null) {
            _error = 'Run not found';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteRun() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Run?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    try {
      await rust_api.deleteRun(id: widget.runId);
      if (mounted) {
        ref.invalidate(runsProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete run: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Run Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _run == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Run Details')),
        body: Center(child: Text(_error ?? 'Run not found')),
      );
    }

    final run = _run!;
    final route = run.points.map((p) => LatLng(p.lat, p.lon)).toList();
    final hasRoute = route.isNotEmpty;
    final center = hasRoute
        ? LatLng(
            route.map((p) => p.latitude).reduce((a, b) => a + b) / route.length,
            route.map((p) => p.longitude).reduce((a, b) => a + b) /
                route.length,
          )
        : const LatLng(51.5074, -0.1278);

    final runDate = DateTime.fromMillisecondsSinceEpoch(run.startTimeMs);

    return Scaffold(
      appBar: AppBar(
        title: Text(run.name ?? 'Run Details'),
        actions: [
          IconButton(
            onPressed: _isDeleting ? null : _deleteRun,
            icon: _isDeleting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline),
            tooltip: 'Delete run',
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date header
              Container(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSizes.paddingSmall),
                    Text(
                      Formatters.formatDateTime(runDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),

              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Distance',
                      value: Formatters.formatDistanceKm(run.distanceMeters),
                      icon: Icons.straighten,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: _StatBox(
                      label: 'Duration',
                      value: Formatters.formatDuration(run.durationMs),
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
                      value: '${Formatters.formatPace(run.avgPaceSecPerKm)}/km',
                      icon: Icons.speed,
                    ),
                  ),
                  const SizedBox(width: AppSizes.paddingSmall),
                  Expanded(
                    child: _StatBox(
                      label: 'Calories',
                      value:
                          '~${(run.distanceMeters / 1000 * 70).round()} kcal',
                      icon: Icons.local_fire_department,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Map
              Container(
                height: 300,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  border: Border.all(color: AppColors.surfaceLight),
                ),
                clipBehavior: Clip.antiAlias,
                child: FlutterMap(
                  options: MapOptions(initialCenter: center, initialZoom: 14.0),
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
                            points: route,
                            color: AppColors.primary,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                  ],
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
