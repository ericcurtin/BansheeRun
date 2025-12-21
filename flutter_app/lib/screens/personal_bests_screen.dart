import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../services/haptic_service.dart';
import '../animations/confetti_celebration.dart';

class PersonalBestsScreen extends StatefulWidget {
  const PersonalBestsScreen({super.key});

  @override
  State<PersonalBestsScreen> createState() => _PersonalBestsScreenState();
}

class _PersonalBestsScreenState extends State<PersonalBestsScreen>
    with TickerProviderStateMixin {
  late AnimationController _trophyController;
  late AnimationController _glowController;
  bool _showConfetti = false;
  int? _celebratingIndex;

  // Demo personal bests
  final List<PersonalBest> _demoPBs = [
    PersonalBest(
      id: '1',
      distanceName: '5K',
      distanceKm: 5.0,
      type: ActivityType.run,
      time: const Duration(minutes: 24, seconds: 35),
      achievedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
    PersonalBest(
      id: '2',
      distanceName: '1K',
      distanceKm: 1.0,
      type: ActivityType.run,
      time: const Duration(minutes: 4, seconds: 12),
      achievedAt: DateTime.now().subtract(const Duration(days: 7)),
    ),
    PersonalBest(
      id: '3',
      distanceName: '10K',
      distanceKm: 10.0,
      type: ActivityType.cycle,
      time: const Duration(minutes: 18, seconds: 45),
      achievedAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
    PersonalBest(
      id: '4',
      distanceName: '5K',
      distanceKm: 5.0,
      type: ActivityType.walk,
      time: const Duration(minutes: 48, seconds: 20),
      achievedAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    PersonalBest(
      id: '5',
      distanceName: '10K',
      distanceKm: 10.0,
      type: ActivityType.run,
      time: const Duration(minutes: 52, seconds: 8),
      achievedAt: DateTime.now().subtract(const Duration(days: 21)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _trophyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _trophyController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _celebrate(int index) {
    setState(() {
      _showConfetti = true;
      _celebratingIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated gradient background
          _buildBackground(),

          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 8),
                _buildTotalStats(),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildPBList(),
                ),
              ],
            ),
          ),

          // Confetti overlay
          ConfettiCelebration(
            isActive: _showConfetti,
            onComplete: () {
              setState(() {
                _showConfetti = false;
                _celebratingIndex = null;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(
                sin(_glowController.value * 2 * pi) * 0.5,
                cos(_glowController.value * 2 * pi) * 0.5,
              ),
              end: Alignment(
                -sin(_glowController.value * 2 * pi) * 0.5,
                -cos(_glowController.value * 2 * pi) * 0.5,
              ),
              colors: const [
                Color(0xFF0D0D1A),
                Color(0xFF1A0F2E),
                Color(0xFF0D1B2A),
                Color(0xFF0D0D1A),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        );
      },
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
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              children: [
                // Animated trophy
                AnimatedBuilder(
                  animation: _trophyController,
                  builder: (context, child) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.orange.withOpacity(0.2),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.3 + _trophyController.value * 0.2),
                            blurRadius: 16 + _trophyController.value * 8,
                            spreadRadius: _trophyController.value * 4,
                          ),
                        ],
                      ),
                      child: const Text(
                        '🏆',
                        style: TextStyle(fontSize: 28),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ).createShader(bounds),
                      child: const Text(
                        'Personal Bests',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      '${_demoPBs.length} records',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: -0.2, end: 0);
  }

  Widget _buildTotalStats() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2A1F4E),
            Color(0xFF1A2F4E),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatColumn(
              icon: Icons.emoji_events,
              iconColor: Colors.amber,
              label: 'TOTAL PBs',
              value: '${_demoPBs.length}',
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.textMuted.withOpacity(0.2),
          ),
          Expanded(
            child: _StatColumn(
              icon: Icons.trending_up,
              iconColor: AppColors.aheadGreen,
              label: 'THIS MONTH',
              value: '3',
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: AppColors.textMuted.withOpacity(0.2),
          ),
          Expanded(
            child: _StatColumn(
              icon: Icons.local_fire_department,
              iconColor: AppColors.runOrange,
              label: 'STREAK',
              value: '7',
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildPBList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: _demoPBs.length,
      itemBuilder: (context, index) {
        final pb = _demoPBs[index];
        final isCelebrating = _celebratingIndex == index;

        return GestureDetector(
          onLongPress: () {
            HapticService.instance.heavyTap();
            _celebrate(index);
          },
          child: _AnimatedPBCard(
            personalBest: pb,
            index: index,
            isHighlighted: isCelebrating,
          ),
        );
      },
    );
  }
}

class _StatColumn extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _StatColumn({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _AnimatedPBCard extends StatefulWidget {
  final PersonalBest personalBest;
  final int index;
  final bool isHighlighted;

  const _AnimatedPBCard({
    required this.personalBest,
    required this.index,
    this.isHighlighted = false,
  });

  @override
  State<_AnimatedPBCard> createState() => _AnimatedPBCardState();
}

class _AnimatedPBCardState extends State<_AnimatedPBCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pb = widget.personalBest;
    final typeColor = pb.type.color;

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        HapticService.instance.lightTap();
      },
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = widget.isHighlighted ? _pulseController.value : 0.0;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()
              ..scale(_isPressed ? 0.98 : 1.0),
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
                color: widget.isHighlighted
                    ? Colors.amber.withOpacity(0.8)
                    : Colors.amber.withOpacity(0.3 + pulseValue * 0.2),
                width: widget.isHighlighted ? 2 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withOpacity(widget.isHighlighted ? 0.4 : 0.2),
                  blurRadius: widget.isHighlighted ? 24 : 16,
                  offset: const Offset(0, 4),
                  spreadRadius: widget.isHighlighted ? 4 : 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // Animated shimmer for highlighted cards
                  if (widget.isHighlighted)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.amber.withOpacity(0.1 + pulseValue * 0.1),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Trophy badge
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            Colors.amber.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _getMedalEmoji(widget.index),
                          style: const TextStyle(fontSize: 20),
                        )
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
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: typeColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pb.type.emoji,
                                style: const TextStyle(fontSize: 20),
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
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.calendar_today,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _formatDate(pb.achievedAt),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Arrow
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
          );
        },
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

  String _getMedalEmoji(int index) {
    switch (index) {
      case 0:
        return '🥇';
      case 1:
        return '🥈';
      case 2:
        return '🥉';
      default:
        return '🏆';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else if (diff.inDays < 30) {
      return '${(diff.inDays / 7).floor()}w ago';
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
