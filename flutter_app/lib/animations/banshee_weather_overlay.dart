import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A full-screen overlay that creates spooky banshee weather effects
/// with animated fog, particles, and vignette based on intensity
class BansheeWeatherOverlay extends StatefulWidget {
  final double intensity; // 0.0 to 1.0
  final bool isActive;

  const BansheeWeatherOverlay({
    super.key,
    this.intensity = 0.0,
    this.isActive = false,
  });

  @override
  State<BansheeWeatherOverlay> createState() => _BansheeWeatherOverlayState();
}

class _BansheeWeatherOverlayState extends State<BansheeWeatherOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fogController;
  late AnimationController _particleController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  late Animation<double> _fadeAnimation;

  final List<_FogLayer> _fogLayers = [];
  final List<_GhostParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _fogController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _initializeFogLayers();
    _initializeParticles();

    if (widget.isActive) {
      _fadeController.forward();
    }
  }

  void _initializeFogLayers() {
    for (int i = 0; i < 4; i++) {
      _fogLayers.add(_FogLayer(
        speed: 0.1 + _random.nextDouble() * 0.3,
        offset: _random.nextDouble() * 2 * pi,
        opacity: 0.1 + _random.nextDouble() * 0.15,
      ));
    }
  }

  void _initializeParticles() {
    for (int i = 0; i < 80; i++) {
      _particles.add(_GhostParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 2 + _random.nextDouble() * 6,
        speedX: (_random.nextDouble() - 0.5) * 0.02,
        speedY: -0.005 - _random.nextDouble() * 0.015,
        phase: _random.nextDouble() * 2 * pi,
        frequency: 0.5 + _random.nextDouble() * 1.5,
      ));
    }
  }

  @override
  void didUpdateWidget(BansheeWeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _fadeController.forward();
      } else {
        _fadeController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _fogController.dispose();
    _particleController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fogController,
        _particleController,
        _pulseController,
        _fadeAnimation,
      ]),
      builder: (context, child) {
        if (_fadeAnimation.value == 0) return const SizedBox.shrink();

        return IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: _BansheeWeatherPainter(
              fogLayers: _fogLayers,
              particles: _particles,
              fogProgress: _fogController.value,
              particleProgress: _particleController.value,
              pulseProgress: _pulseController.value,
              intensity: widget.intensity,
              masterOpacity: _fadeAnimation.value,
            ),
          ),
        );
      },
    );
  }
}

class _FogLayer {
  final double speed;
  final double offset;
  final double opacity;

  _FogLayer({
    required this.speed,
    required this.offset,
    required this.opacity,
  });
}

class _GhostParticle {
  double x;
  double y;
  final double size;
  final double speedX;
  final double speedY;
  final double phase;
  final double frequency;

  _GhostParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.phase,
    required this.frequency,
  });
}

class _BansheeWeatherPainter extends CustomPainter {
  final List<_FogLayer> fogLayers;
  final List<_GhostParticle> particles;
  final double fogProgress;
  final double particleProgress;
  final double pulseProgress;
  final double intensity;
  final double masterOpacity;

  _BansheeWeatherPainter({
    required this.fogLayers,
    required this.particles,
    required this.fogProgress,
    required this.particleProgress,
    required this.pulseProgress,
    required this.intensity,
    required this.masterOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scaledIntensity = intensity * masterOpacity;
    if (scaledIntensity == 0) return;

    // Draw fog layers
    _drawFogLayers(canvas, size, scaledIntensity);

    // Draw ghost particles
    _drawParticles(canvas, size, scaledIntensity);

    // Draw vignette
    _drawVignette(canvas, size, scaledIntensity);

    // Draw pulsing glow at edges
    _drawEdgeGlow(canvas, size, scaledIntensity);
  }

  void _drawFogLayers(Canvas canvas, Size size, double scaledIntensity) {
    for (int i = 0; i < fogLayers.length; i++) {
      final layer = fogLayers[i];
      final xOffset = sin(fogProgress * 2 * pi * layer.speed + layer.offset) * size.width * 0.3;
      final yOffset = cos(fogProgress * 2 * pi * layer.speed * 0.7 + layer.offset) * size.height * 0.1;

      final paint = Paint()
        ..shader = RadialGradient(
          center: Alignment(
            (0.5 + xOffset / size.width).clamp(0.0, 1.0) * 2 - 1,
            (0.3 + i * 0.15 + yOffset / size.height).clamp(0.0, 1.0) * 2 - 1,
          ),
          radius: 1.5,
          colors: [
            AppColors.bansheeGreen.withOpacity(layer.opacity * scaledIntensity),
            AppColors.bansheeGlow.withOpacity(layer.opacity * 0.5 * scaledIntensity),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    }
  }

  void _drawParticles(Canvas canvas, Size size, double scaledIntensity) {
    final particleTime = particleProgress * 2 * pi;

    for (final particle in particles) {
      // Update position with wrapping
      final x = (particle.x + particle.speedX * particleProgress * 10 +
              sin(particleTime * particle.frequency + particle.phase) * 0.02) %
          1.0;
      final y = (particle.y + particle.speedY * particleProgress * 10) % 1.0;

      final screenX = x * size.width;
      final screenY = y * size.height;

      // Pulsing opacity
      final alpha = (0.3 + sin(particleTime * particle.frequency + particle.phase) * 0.3)
          .clamp(0.0, 1.0);

      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.ghostWhite.withOpacity(alpha * scaledIntensity * 0.8),
            AppColors.bansheeGlow.withOpacity(alpha * scaledIntensity * 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(screenX, screenY),
          radius: particle.size * (1 + scaledIntensity),
        ));

      canvas.drawCircle(
        Offset(screenX, screenY),
        particle.size * (1 + scaledIntensity),
        paint,
      );
    }
  }

  void _drawVignette(Canvas canvas, Size size, double scaledIntensity) {
    final vignetteIntensity = scaledIntensity * 0.6;

    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          Colors.transparent,
          AppColors.darkBackground.withOpacity(vignetteIntensity * 0.3),
          AppColors.darkBackground.withOpacity(vignetteIntensity * 0.7),
          AppColors.darkBackground.withOpacity(vignetteIntensity),
        ],
        stops: const [0.3, 0.6, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  void _drawEdgeGlow(Canvas canvas, Size size, double scaledIntensity) {
    final glowOpacity = (0.2 + pulseProgress * 0.3) * scaledIntensity;

    // Top glow
    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          AppColors.bansheeGreen.withOpacity(glowOpacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.3));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.3), topPaint);

    // Bottom glow
    final bottomPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.center,
        colors: [
          AppColors.primaryPurple.withOpacity(glowOpacity * 0.7),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      bottomPaint,
    );
  }

  @override
  bool shouldRepaint(_BansheeWeatherPainter oldDelegate) => true;
}
