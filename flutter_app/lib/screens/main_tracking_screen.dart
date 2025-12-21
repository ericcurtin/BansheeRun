import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../models/activity.dart';
import '../widgets/animated_stat_card.dart';
import '../widgets/gradient_button.dart';
import '../widgets/activity_type_selector.dart';
import '../animations/banshee_weather_overlay.dart';
import '../services/haptic_service.dart';

class MainTrackingScreen extends StatefulWidget {
  const MainTrackingScreen({super.key});

  @override
  State<MainTrackingScreen> createState() => _MainTrackingScreenState();
}

class _MainTrackingScreenState extends State<MainTrackingScreen>
    with TickerProviderStateMixin {
  ActivityType _selectedType = ActivityType.run;
  bool _isTracking = false;
  PacingStatus _pacingStatus = PacingStatus.unknown;

  // Demo stats
  double _distance = 0.0;
  Duration _elapsed = Duration.zero;
  double _bansheeIntensity = 0.0;
  String _timeDifference = '+0:00';

  Timer? _demoTimer;
  late AnimationController _mapGlowController;

  @override
  void initState() {
    super.initState();
    _mapGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _mapGlowController.dispose();
    super.dispose();
  }

  void _toggleTracking() {
    setState(() {
      _isTracking = !_isTracking;
    });

    if (_isTracking) {
      _startDemoTracking();
    } else {
      _stopDemoTracking();
    }
  }

  void _startDemoTracking() {
    _demoTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed += const Duration(seconds: 1);
        _distance += 0.005 + Random().nextDouble() * 0.003;

        // Simulate pacing changes
        final randomChange = Random().nextDouble();
        if (randomChange < 0.3) {
          _pacingStatus = PacingStatus.ahead;
          _bansheeIntensity = max(0, _bansheeIntensity - 0.1);
          _timeDifference = '+${Random().nextInt(30)}s';
        } else if (randomChange < 0.6) {
          _pacingStatus = PacingStatus.behind;
          _bansheeIntensity = min(1, _bansheeIntensity + 0.15);
          _timeDifference = '-${Random().nextInt(30)}s';

          // Haptic feedback when falling behind
          if (_bansheeIntensity > 0.5) {
            HapticService.instance.bansheeApproaching(_bansheeIntensity);
          }
        }
      });
    });
  }

  void _stopDemoTracking() {
    _demoTimer?.cancel();
    setState(() {
      _bansheeIntensity = 0.0;
      _pacingStatus = PacingStatus.unknown;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map area (placeholder with animated gradient)
          _buildMapArea(),

          // Banshee weather overlay
          BansheeWeatherOverlay(
            intensity: _bansheeIntensity,
            isActive: _isTracking && _pacingStatus == PacingStatus.behind,
          ),

          // Bottom panel
          _buildBottomPanel(),

          // Top status bar
          _buildTopStatusBar(),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return AnimatedBuilder(
      animation: _mapGlowController,
      builder: (context, child) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.55,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(
                sin(_mapGlowController.value * 2 * pi) * 0.3,
                cos(_mapGlowController.value * 2 * pi) * 0.3,
              ),
              radius: 1.5,
              colors: [
                AppColors.surfaceColor,
                AppColors.darkBackground,
                AppColors.cardBackground,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Grid pattern
              CustomPaint(
                size: Size.infinite,
                painter: _GridPainter(
                  progress: _mapGlowController.value,
                  color: AppColors.primaryCyan.withOpacity(0.1),
                ),
              ),
              // Center marker
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _selectedType.color.withOpacity(0.3),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _selectedType.color.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.my_location,
                        color: _selectedType.color,
                        size: 32,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.1, 1.1),
                          duration: 1500.ms,
                        ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _selectedType.color.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _isTracking ? 'Tracking Active' : 'Map View',
                        style: TextStyle(
                          color: _selectedType.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Wandering banshee indicator when behind
              if (_isTracking && _pacingStatus == PacingStatus.behind)
                _WanderingBansheeIndicator(intensity: _bansheeIntensity),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBackground.withOpacity(0.0),
              AppColors.darkBackground,
              AppColors.darkBackground,
            ],
            stops: const [0.0, 0.15, 1.0],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pacing indicator
                if (_isTracking)
                  AnimatedPacingIndicator(
                    status: _pacingStatus.displayName,
                    color: _pacingStatus.color,
                    icon: _pacingStatus.icon,
                    timeDifference: _timeDifference,
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .slideY(begin: 0.3, end: 0),

                const SizedBox(height: 16),

                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: AnimatedStatCard(
                        label: 'DISTANCE',
                        value: '${_distance.toStringAsFixed(2)} km',
                        icon: Icons.straighten,
                        accentColor: AppColors.primaryCyan,
                        animationDelay: 0,
                        isPulsing: _isTracking,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedStatCard(
                        label: 'TIME',
                        value: _formatDuration(_elapsed),
                        icon: Icons.timer,
                        accentColor: AppColors.primaryMagenta,
                        animationDelay: 100,
                        isPulsing: _isTracking,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Activity type selector
                ActivityTypeSelector(
                  selectedType: _selectedType,
                  onTypeChanged: (type) {
                    setState(() => _selectedType = type);
                  },
                ),

                const SizedBox(height: 20),

                // Control buttons row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Activities button
                    _NavButton(
                      icon: Icons.history,
                      label: 'Activities',
                      onTap: () => _navigateToActivities(),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideX(begin: -0.3, end: 0),

                    // Start/Stop button
                    PulsingStartButton(
                      isRunning: _isTracking,
                      onPressed: _toggleTracking,
                    ),

                    // Personal Bests button
                    _NavButton(
                      icon: Icons.emoji_events,
                      label: 'Records',
                      onTap: () => _navigateToPersonalBests(),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideX(begin: 0.3, end: 0),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopStatusBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.darkBackground,
              AppColors.darkBackground.withOpacity(0.8),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Logo / Title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.bansheeGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.bansheeGreen.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Text('👻', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.bansheeGradient.createShader(bounds),
                      child: const Text(
                        'BansheeRun',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .slideX(begin: -0.2, end: 0),
                const Spacer(),
                // Banshee mode indicator
                if (_isTracking)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bansheeGreen.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.bansheeGreen.withOpacity(0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.bansheeGreen,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.bansheeGreen,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        )
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .fade(begin: 0.5, end: 1, duration: 500.ms),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE',
                          style: TextStyle(
                            color: AppColors.bansheeGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 300.ms)
                      .scale(begin: const Offset(0.8, 0.8)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _navigateToActivities() {
    HapticService.instance.lightTap();
    Navigator.pushNamed(context, '/activities');
  }

  void _navigateToPersonalBests() {
    HapticService.instance.lightTap();
    Navigator.pushNamed(context, '/personal-bests');
  }
}

class _NavButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
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
        transform: Matrix4.identity()..scale(_isPressed ? 0.9 : 1.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.textMuted.withOpacity(0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.icon,
              color: AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WanderingBansheeIndicator extends StatefulWidget {
  final double intensity;

  const _WanderingBansheeIndicator({required this.intensity});

  @override
  State<_WanderingBansheeIndicator> createState() =>
      _WanderingBansheeIndicatorState();
}

class _WanderingBansheeIndicatorState extends State<_WanderingBansheeIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * pi;
        final radius = 100 - widget.intensity * 50;

        return Positioned(
          left: MediaQuery.of(context).size.width / 2 + cos(angle) * radius - 25,
          top: MediaQuery.of(context).size.height * 0.25 + sin(angle) * radius - 25,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.bansheeGreen.withOpacity(0.6 + widget.intensity * 0.4),
                  AppColors.bansheeGlow.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.bansheeGreen.withOpacity(0.5),
                  blurRadius: 20 + widget.intensity * 20,
                  spreadRadius: widget.intensity * 10,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '👻',
                style: TextStyle(
                  fontSize: 28,
                  shadows: [
                    Shadow(
                      color: AppColors.bansheeGreen,
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final double progress;
  final Color color;

  _GridPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const spacing = 40.0;
    final offset = (progress * spacing) % spacing;

    // Vertical lines
    for (double x = offset; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Horizontal lines
    for (double y = offset; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
