import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../widgets/activity_card.dart';
import '../widgets/activity_type_selector.dart';
import '../services/haptic_service.dart';

class ActivityListScreen extends StatefulWidget {
  const ActivityListScreen({super.key});

  @override
  State<ActivityListScreen> createState() => _ActivityListScreenState();
}

class _ActivityListScreenState extends State<ActivityListScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Run', 'Walk', 'Cycle', 'Skate'];

  // Demo activities
  final List<Activity> _demoActivities = [
    Activity(
      id: '1',
      name: 'Morning Run',
      type: ActivityType.run,
      startTime: DateTime.now().subtract(const Duration(hours: 2)),
      endTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)),
      distanceKm: 5.23,
      duration: const Duration(minutes: 28, seconds: 45),
      points: [],
    ),
    Activity(
      id: '2',
      name: 'Evening Walk',
      type: ActivityType.walk,
      startTime: DateTime.now().subtract(const Duration(days: 1, hours: 18)),
      endTime: DateTime.now().subtract(const Duration(days: 1, hours: 17)),
      distanceKm: 3.15,
      duration: const Duration(minutes: 45, seconds: 12),
      points: [],
    ),
    Activity(
      id: '3',
      name: 'Weekend Cycle',
      type: ActivityType.cycle,
      startTime: DateTime.now().subtract(const Duration(days: 2)),
      endTime: DateTime.now().subtract(const Duration(days: 2)).add(const Duration(hours: 1, minutes: 15)),
      distanceKm: 25.8,
      duration: const Duration(hours: 1, minutes: 15, seconds: 30),
      points: [],
    ),
    Activity(
      id: '4',
      name: 'Park Sprint',
      type: ActivityType.run,
      startTime: DateTime.now().subtract(const Duration(days: 3)),
      endTime: DateTime.now().subtract(const Duration(days: 3)).add(const Duration(minutes: 22)),
      distanceKm: 4.0,
      duration: const Duration(minutes: 22, seconds: 10),
      points: [],
    ),
    Activity(
      id: '5',
      name: 'City Skate',
      type: ActivityType.skate,
      startTime: DateTime.now().subtract(const Duration(days: 5)),
      endTime: DateTime.now().subtract(const Duration(days: 5)).add(const Duration(minutes: 50)),
      distanceKm: 8.5,
      duration: const Duration(minutes: 50, seconds: 0),
      points: [],
    ),
  ];

  List<Activity> get _filteredActivities {
    if (_selectedFilter == 'All') {
      return _demoActivities;
    }
    return _demoActivities.where((a) {
      return a.type.displayName == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.surfaceColor,
              AppColors.darkBackground,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              FilterChips(
                options: _filters,
                selectedOption: _selectedFilter,
                onSelected: (filter) {
                  setState(() => _selectedFilter = filter);
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _filteredActivities.isEmpty
                    ? _buildEmptyState()
                    : _buildActivityList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticService.instance.lightTap();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.textMuted.withOpacity(0.2),
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activities',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_demoActivities.length} total activities',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _buildStatsButton(),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.2, end: 0);
  }

  Widget _buildStatsButton() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryCyan.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.bar_chart,
        color: AppColors.darkBackground,
        size: 24,
      ),
    );
  }

  Widget _buildActivityList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _filteredActivities.length,
      itemBuilder: (context, index) {
        final activity = _filteredActivities[index];
        return ActivityCard(
          activity: activity,
          index: index,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/activity-detail',
              arguments: activity,
            );
          },
          onBansheeMode: () {
            HapticService.instance.mediumTap();
            _showBansheeModeDialog(activity);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withOpacity(0.2),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.directions_run,
              size: 48,
              color: AppColors.textMuted,
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.1, 1.1),
                duration: 1500.ms,
              ),
          const SizedBox(height: 24),
          Text(
            'No activities yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start tracking to see your activities here',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .scale(begin: const Offset(0.9, 0.9));
  }

  void _showBansheeModeDialog(Activity activity) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppColors.bansheeGreen.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.bansheeGreen.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Text('👻', style: TextStyle(fontSize: 48)),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.15, 1.15),
                  duration: 800.ms,
                ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.bansheeGradient.createShader(bounds),
              child: const Text(
                'Banshee Mode',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Race against "${activity.name}"',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMiniStat(
                  Icons.straighten,
                  activity.formattedDistance,
                ),
                const SizedBox(width: 24),
                _buildMiniStat(
                  Icons.timer,
                  activity.formattedDuration,
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  HapticService.instance.activityStarted();
                  Navigator.pop(context);
                  Navigator.pushReplacementNamed(context, '/');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.bansheeGreen,
                        AppColors.bansheeGlow,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.bansheeGreen.withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_arrow,
                        color: AppColors.darkBackground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'START CHASE',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkBackground,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
                .animate()
                .shimmer(
                  duration: 2.seconds,
                  color: Colors.white.withOpacity(0.3),
                ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
