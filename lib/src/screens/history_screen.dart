import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';
import 'package:banshee_run_app/src/rust/api/run_api.dart' as rust_api;
import 'package:banshee_run_app/src/screens/run_detail_screen.dart';

final runsProvider = FutureProvider<List<rust_api.RunSummaryDto>>((ref) async {
  return await rust_api.getAllRuns();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(runsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Run History')),
      body: runsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading runs: $error')),
        data: (runs) => runs.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history,
                      size: 64,
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: AppSizes.paddingMedium),
                    Text(
                      'No runs yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.paddingSmall),
                    Text(
                      'Complete your first run to see it here',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(AppSizes.paddingMedium),
                itemCount: runs.length,
                itemBuilder: (context, index) {
                  final run = runs[index];
                  return _RunCard(
                    name: run.name,
                    date: DateTime.fromMillisecondsSinceEpoch(run.startTimeMs),
                    distanceM: run.distanceMeters,
                    durationMs: run.durationMs,
                    paceSecPerKm: run.avgPaceSecPerKm,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => RunDetailScreen(runId: run.id),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  final String? name;
  final DateTime date;
  final double distanceM;
  final int durationMs;
  final double? paceSecPerKm;
  final VoidCallback onTap;

  const _RunCard({
    this.name,
    required this.date,
    required this.distanceM,
    required this.durationMs,
    this.paceSecPerKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      name ?? 'Run',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    Formatters.formatRelativeTime(date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingSmall),
              Row(
                children: [
                  _Stat(
                    icon: Icons.straighten,
                    value: Formatters.formatDistanceKm(distanceM),
                  ),
                  const SizedBox(width: AppSizes.paddingMedium),
                  _Stat(
                    icon: Icons.timer,
                    value: Formatters.formatDuration(durationMs),
                  ),
                  const SizedBox(width: AppSizes.paddingMedium),
                  _Stat(
                    icon: Icons.speed,
                    value: '${Formatters.formatPace(paceSecPerKm)}/km',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}
