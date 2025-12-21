import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/activity.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

class ActivityCard extends StatefulWidget {
  final Activity activity;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onBansheeMode;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.index,
    required this.onTap,
    this.onBansheeMode,
  });

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;
    final typeColor = activity.type.color;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticService.instance.lightTap();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBackground,
                AppColors.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: typeColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: AppColors.darkBackground.withOpacity(0.5),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Accent gradient strip on the left
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          typeColor,
                          typeColor.withOpacity(0.5),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Activity type icon with animated background
                      _buildActivityIcon(activity, typeColor),
                      const SizedBox(width: 16),
                      // Activity details
                      Expanded(
                        child: _buildActivityDetails(activity, typeColor),
                      ),
                      // Banshee mode button
                      if (widget.onBansheeMode != null)
                        _buildBansheeModeButton(typeColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 50 * widget.index))
        .fadeIn(duration: 400.ms)
        .slideX(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }

  Widget _buildActivityIcon(Activity activity, Color typeColor) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [
            typeColor.withOpacity(0.2),
            typeColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: typeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          activity.type.emoji,
          style: const TextStyle(fontSize: 28),
        ),
      ),
    );
  }

  Widget _buildActivityDetails(Activity activity, Color typeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                activity.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _buildStatChip(
              Icons.straighten,
              activity.formattedDistance,
              typeColor,
            ),
            const SizedBox(width: 12),
            _buildStatChip(
              Icons.timer_outlined,
              activity.formattedDuration,
              typeColor,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _formatDate(activity.startTime),
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: color.withOpacity(0.8),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBansheeModeButton(Color typeColor) {
    return GestureDetector(
      onTap: () {
        HapticService.instance.mediumTap();
        widget.onBansheeMode?.call();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.bansheeGreen.withOpacity(0.2),
              AppColors.bansheeGlow.withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.bansheeGreen.withOpacity(0.4),
            width: 1,
          ),
        ),
        child: const Icon(
          Icons.flash_on,
          color: AppColors.bansheeGreen,
          size: 24,
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .shimmer(
            duration: 2.seconds,
            color: AppColors.bansheeGlow.withOpacity(0.3),
          ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today at ${_formatTime(date)}';
    } else if (diff.inDays == 1) {
      return 'Yesterday at ${_formatTime(date)}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class PersonalBestCard extends StatefulWidget {
  final PersonalBest personalBest;
  final int index;
  final VoidCallback? onTap;

  const PersonalBestCard({
    super.key,
    required this.personalBest,
    required this.index,
    this.onTap,
  });

  @override
  State<PersonalBestCard> createState() => _PersonalBestCardState();
}

class _PersonalBestCardState extends State<PersonalBestCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final pb = widget.personalBest;
    final typeColor = pb.type.color;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticService.instance.lightTap();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.cardBackground,
                AppColors.surfaceColor,
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.amber.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.amber.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Trophy badge
                Positioned(
                  right: -10,
                  top: -10,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          Colors.amber.withOpacity(0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: const Text('🏆', style: TextStyle(fontSize: 24))
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scale(
                            begin: const Offset(1, 1),
                            end: const Offset(1.1, 1.1),
                            duration: 1.seconds,
                          ),
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Distance badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              typeColor.withOpacity(0.3),
                              typeColor.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: typeColor.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              pb.distanceName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pb.type.emoji,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Stats
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Colors.amber, Colors.orange],
                              ).createShader(bounds),
                              child: Text(
                                pb.formattedTime,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.speed,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  pb.formattedPace,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Chevron
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 100 * widget.index))
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
        .shimmer(
          delay: Duration(milliseconds: 500 + 100 * widget.index),
          duration: 1.seconds,
          color: Colors.amber.withOpacity(0.2),
        );
  }
}
