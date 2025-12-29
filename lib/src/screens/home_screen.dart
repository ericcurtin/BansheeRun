import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/screens/run_setup_screen.dart';
import 'package:banshee_run_app/src/screens/history_screen.dart';
import 'package:banshee_run_app/src/screens/settings_screen.dart';
import 'package:banshee_run_app/src/screens/run_detail_screen.dart';
import 'package:banshee_run_app/src/providers/location_provider.dart';
import 'package:banshee_run_app/src/providers/run_provider.dart';
import 'package:banshee_run_app/src/utils/constants.dart';
import 'package:banshee_run_app/src/utils/formatters.dart';
import 'package:banshee_run_app/src/widgets/stats_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Start acquiring GPS location as soon as the app opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(locationNotifierProvider.notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.appName,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Race your banshee',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.settings,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Stats overview
              Consumer(
                builder: (context, ref, child) {
                  final statsAsync = ref.watch(totalStatsProvider);
                  return statsAsync.when(
                    loading: () => Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Total Runs',
                            value: '...',
                            icon: Icons.directions_run,
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingMedium),
                        Expanded(
                          child: StatsCard(
                            title: 'Total Distance',
                            value: '...',
                            icon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                    error: (_, _) => Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Total Runs',
                            value: '0',
                            icon: Icons.directions_run,
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingMedium),
                        Expanded(
                          child: StatsCard(
                            title: 'Total Distance',
                            value: '0.0 km',
                            icon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                    data: (stats) => Row(
                      children: [
                        Expanded(
                          child: StatsCard(
                            title: 'Total Runs',
                            value: '${stats.runCount}',
                            icon: Icons.directions_run,
                          ),
                        ),
                        const SizedBox(width: AppSizes.paddingMedium),
                        Expanded(
                          child: StatsCard(
                            title: 'Total Distance',
                            value: Formatters.formatDistanceKm(
                              stats.totalDistance,
                            ),
                            icon: Icons.straighten,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Start Run Button
              SizedBox(
                height: 120,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RunSetupScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadius,
                      ),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        AppStrings.startRun,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.paddingLarge),

              // Recent runs header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Runs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryScreen(),
                        ),
                      );
                    },
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.paddingSmall),

              // Recent runs list
              Expanded(
                child: Consumer(
                  builder: (context, ref, child) {
                    final runsAsync = ref.watch(runsProvider);
                    return runsAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(
                        child: Text(
                          'Error loading runs',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      data: (runs) {
                        if (runs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_run,
                                  size: 64,
                                  color: AppColors.textSecondary.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                                const SizedBox(height: AppSizes.paddingMedium),
                                Text(
                                  'No runs yet',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Start your first run to see it here',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.7),
                                      ),
                                ),
                              ],
                            ),
                          );
                        }
                        // Show up to 3 recent runs
                        final recentRuns = runs.take(3).toList();
                        return ListView.builder(
                          itemCount: recentRuns.length,
                          itemBuilder: (context, index) {
                            final run = recentRuns[index];
                            return Card(
                              margin: const EdgeInsets.only(
                                bottom: AppSizes.paddingSmall,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  child: Icon(
                                    Icons.directions_run,
                                    color: AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  run.name ?? 'Run',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  '${Formatters.formatDistanceKm(run.distanceMeters)} • ${Formatters.formatDuration(run.durationMs)}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                trailing: Text(
                                  Formatters.formatRelativeTime(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      run.startTimeMs,
                                    ),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          RunDetailScreen(runId: run.id),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
