import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/screens/active_run_screen.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/widgets/pace_selector.dart';

enum BansheeMode { none, previousRun, aiPacer }

class RunSetupScreen extends ConsumerStatefulWidget {
  const RunSetupScreen({super.key});

  @override
  ConsumerState<RunSetupScreen> createState() => _RunSetupScreenState();
}

class _RunSetupScreenState extends ConsumerState<RunSetupScreen> {
  BansheeMode _selectedMode = BansheeMode.none;
  double _targetPaceSecPerKm = 360.0; // Default 6:00/km
  String? _selectedRunId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Run'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choose your banshee',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSizes.paddingMedium),

              // Banshee mode options
              _BansheeModeCard(
                title: 'No Banshee',
                subtitle: 'Run freely without a pacer',
                icon: Icons.person,
                isSelected: _selectedMode == BansheeMode.none,
                onTap: () => setState(() => _selectedMode = BansheeMode.none),
              ),
              const SizedBox(height: AppSizes.paddingSmall),

              _BansheeModeCard(
                title: 'Previous Run',
                subtitle: 'Race against your past performance',
                icon: Icons.history,
                isSelected: _selectedMode == BansheeMode.previousRun,
                onTap: () =>
                    setState(() => _selectedMode = BansheeMode.previousRun),
              ),
              const SizedBox(height: AppSizes.paddingSmall),

              _BansheeModeCard(
                title: 'AI Pacer',
                subtitle: 'Set a target pace to follow',
                icon: Icons.speed,
                isSelected: _selectedMode == BansheeMode.aiPacer,
                onTap: () =>
                    setState(() => _selectedMode = BansheeMode.aiPacer),
              ),

              // AI Pacer settings
              if (_selectedMode == BansheeMode.aiPacer) ...[
                const SizedBox(height: AppSizes.paddingLarge),
                PaceSelector(
                  initialPaceSecPerKm: _targetPaceSecPerKm,
                  onPaceChanged: (pace) {
                    setState(() => _targetPaceSecPerKm = pace);
                  },
                ),
              ],

              // Previous run selection (placeholder)
              if (_selectedMode == BansheeMode.previousRun) ...[
                const SizedBox(height: AppSizes.paddingLarge),
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingMedium),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadius),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: AppSizes.paddingSmall),
                      Text(
                        'No previous runs available',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),

              // Start button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActiveRunScreen(
                          bansheeMode: _selectedMode,
                          targetPaceSecPerKm:
                              _selectedMode == BansheeMode.aiPacer
                              ? _targetPaceSecPerKm
                              : null,
                          bansheeRunId: _selectedRunId,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    'Start Run',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

class _BansheeModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _BansheeModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.paddingMedium),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.borderRadius),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSizes.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
