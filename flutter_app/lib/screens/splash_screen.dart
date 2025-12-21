import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';
import '../animations/particle_explosion.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late AnimationController _particleController;
  bool _showParticles = false;
  bool _navigationTriggered = false;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _startAnimation();
  }

  void _startAnimation() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();

    await Future.delayed(const Duration(milliseconds: 800));
    HapticService.instance.mediumTap();

    await Future.delayed(const Duration(milliseconds: 400));
    setState(() => _showParticles = true);
    _particleController.forward();
    HapticService.instance.success();

    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateToHome();
  }

  void _navigateToHome() {
    if (_navigationTriggered) return;
    _navigationTriggered = true;

    HapticService.instance.lightTap();
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToHome,
      child: Scaffold(
        body: Stack(
          children: [
            // Animated gradient background
            AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(
                        cos(_backgroundController.value * 2 * pi),
                        sin(_backgroundController.value * 2 * pi),
                      ),
                      end: Alignment(
                        -cos(_backgroundController.value * 2 * pi),
                        -sin(_backgroundController.value * 2 * pi),
                      ),
                      colors: const [
                        AppColors.darkBackground,
                        Color(0xFF1A0A2E),
                        AppColors.surfaceColor,
                        Color(0xFF0A1628),
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                );
              },
            ),

            // Floating orbs in background
            ..._buildFloatingOrbs(),

            // Particle explosion effect
            if (_showParticles)
              Center(
                child: ParticleExplosion(
                  controller: _particleController,
                  particleCount: 100,
                  colors: const [
                    AppColors.bansheeGreen,
                    AppColors.bansheeGlow,
                    AppColors.primaryCyan,
                    AppColors.primaryMagenta,
                    AppColors.primaryPurple,
                  ],
                ),
              ),

            // Main logo and text
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Glowing ghost emoji
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.bansheeGreen.withOpacity(0.3),
                          AppColors.bansheeGlow.withOpacity(0.1),
                          Colors.transparent,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.bansheeGreen.withOpacity(0.5),
                          blurRadius: 60,
                          spreadRadius: 20,
                        ),
                      ],
                    ),
                    child: const Text(
                      '👻',
                      style: TextStyle(fontSize: 80),
                    ),
                  )
                      .animate(controller: _logoController)
                      .scale(
                        begin: const Offset(0, 0),
                        end: const Offset(1, 1),
                        duration: 800.ms,
                        curve: Curves.elasticOut,
                      )
                      .then()
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.05, 1.05),
                        duration: 1500.ms,
                      ),

                  const SizedBox(height: 32),

                  // App name with gradient
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        AppColors.bansheeGreen,
                        AppColors.bansheeGlow,
                        AppColors.ghostWhite,
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'BansheeRun',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  )
                      .animate(controller: _logoController)
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0),

                  const SizedBox(height: 12),

                  // Tagline
                  Text(
                    'Race your ghost. Beat your past.',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 1,
                    ),
                  )
                      .animate(controller: _logoController)
                      .fadeIn(delay: 700.ms, duration: 500.ms)
                      .slideY(begin: 0.5, end: 0),
                ],
              ),
            ),

            // Bottom gradient fade
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.primaryPurple.withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Loading indicator at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 60,
              child: Center(
                child: Container(
                  width: 200,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.transparent,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.bansheeGreen,
                      ),
                    )
                        .animate(controller: _logoController)
                        .fadeIn(delay: 500.ms, duration: 300.ms),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFloatingOrbs() {
    final random = Random(42);
    final orbs = <Widget>[];
    final colors = [
      AppColors.bansheeGreen,
      AppColors.primaryCyan,
      AppColors.primaryMagenta,
      AppColors.primaryPurple,
    ];

    for (int i = 0; i < 8; i++) {
      final size = 30.0 + random.nextDouble() * 60;
      final left = random.nextDouble() * MediaQuery.of(context).size.width;
      final top = random.nextDouble() * MediaQuery.of(context).size.height;
      final color = colors[random.nextInt(colors.length)];
      final duration = 3000 + random.nextInt(4000);

      orbs.add(
        Positioned(
          left: left,
          top: top,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.4),
                  color.withOpacity(0.1),
                  Colors.transparent,
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveX(
                begin: 0,
                end: random.nextDouble() * 40 - 20,
                duration: Duration(milliseconds: duration),
              )
              .moveY(
                begin: 0,
                end: random.nextDouble() * 40 - 20,
                duration: Duration(milliseconds: duration + 500),
              )
              .fade(
                begin: 0.3,
                end: 0.8,
                duration: Duration(milliseconds: duration),
              ),
        ),
      );
    }

    return orbs;
  }
}
