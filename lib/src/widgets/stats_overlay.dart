import 'package:flutter/material.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';

class StatsOverlay extends StatelessWidget {
  final int elapsedMs;
  final double distanceM;
  final double currentPaceSecPerKm;
  final double? bansheeDeltaM;
  final bool isPaused;

  const StatsOverlay({
    super.key,
    required this.elapsedMs,
    required this.distanceM,
    required this.currentPaceSecPerKm,
    this.bansheeDeltaM,
    this.isPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSizes.paddingMedium),
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Paused indicator
          if (isPaused)
            Container(
              margin: const EdgeInsets.only(bottom: AppSizes.paddingSmall),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),

          // Main stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                value: Formatters.formatDuration(elapsedMs),
                label: 'Time',
              ),
              _StatItem(
                value: Formatters.formatDistanceKm(distanceM),
                label: 'Distance',
              ),
              _StatItem(
                value: '${Formatters.formatPace(currentPaceSecPerKm)}/km',
                label: 'Pace',
              ),
            ],
          ),

          // Banshee delta (if racing)
          if (bansheeDeltaM != null) ...[
            const Divider(color: AppColors.surfaceLight, height: 24),
            _BansheeDeltaDisplay(deltaM: bansheeDeltaM!),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
    );
  }
}

class _BansheeDeltaDisplay extends StatelessWidget {
  final double deltaM;

  const _BansheeDeltaDisplay({required this.deltaM});

  @override
  Widget build(BuildContext context) {
    final isAhead = deltaM < 0;
    final color = isAhead ? AppColors.bansheeBehind : AppColors.bansheeAhead;
    final icon = isAhead ? Icons.arrow_upward : Icons.arrow_downward;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.directions_run, color: color, size: 20),
        const SizedBox(width: 8),
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 4),
        Text(
          Formatters.formatBansheeDelta(deltaM),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
