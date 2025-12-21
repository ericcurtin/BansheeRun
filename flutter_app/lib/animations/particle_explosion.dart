import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A colorful particle explosion animation that bursts from the center
class ParticleExplosion extends StatefulWidget {
  final AnimationController controller;
  final int particleCount;
  final List<Color> colors;
  final double maxRadius;

  const ParticleExplosion({
    super.key,
    required this.controller,
    this.particleCount = 80,
    this.colors = const [
      AppColors.bansheeGreen,
      AppColors.primaryCyan,
      AppColors.primaryMagenta,
    ],
    this.maxRadius = 300,
  });

  @override
  State<ParticleExplosion> createState() => _ParticleExplosionState();
}

class _ParticleExplosionState extends State<ParticleExplosion> {
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initializeParticles();
  }

  void _initializeParticles() {
    _particles = List.generate(widget.particleCount, (index) {
      final angle = _random.nextDouble() * 2 * pi;
      final velocity = 0.5 + _random.nextDouble() * 0.5;
      final size = 3.0 + _random.nextDouble() * 8;
      final color = widget.colors[_random.nextInt(widget.colors.length)];
      final rotationSpeed = (_random.nextDouble() - 0.5) * 4;
      final lifetime = 0.6 + _random.nextDouble() * 0.4;

      return _Particle(
        angle: angle,
        velocity: velocity,
        size: size,
        color: color,
        rotationSpeed: rotationSpeed,
        lifetime: lifetime,
        isSparkle: _random.nextDouble() > 0.7,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.maxRadius * 2, widget.maxRadius * 2),
          painter: _ParticleExplosionPainter(
            particles: _particles,
            progress: widget.controller.value,
            maxRadius: widget.maxRadius,
          ),
        );
      },
    );
  }
}

class _Particle {
  final double angle;
  final double velocity;
  final double size;
  final Color color;
  final double rotationSpeed;
  final double lifetime;
  final bool isSparkle;

  _Particle({
    required this.angle,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.lifetime,
    required this.isSparkle,
  });
}

class _ParticleExplosionPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final double maxRadius;

  _ParticleExplosionPainter({
    required this.particles,
    required this.progress,
    required this.maxRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      // Check if particle is still alive
      if (progress > particle.lifetime) continue;

      final normalizedProgress = progress / particle.lifetime;

      // Ease out effect for natural deceleration
      final easedProgress = 1 - pow(1 - normalizedProgress, 3);

      // Calculate position with gravity effect
      final distance = easedProgress * maxRadius * particle.velocity;
      final gravityOffset = pow(normalizedProgress, 2) * 50;

      final x = center.dx + cos(particle.angle) * distance;
      final y = center.dy + sin(particle.angle) * distance + gravityOffset;

      // Fade out near end of life
      final alpha = (1 - pow(normalizedProgress, 2)).clamp(0.0, 1.0).toDouble();

      // Scale down near end
      final scale = (1 - normalizedProgress * 0.5).clamp(0.0, 1.0);
      final currentSize = particle.size * scale;

      final paint = Paint()
        ..color = particle.color.withOpacity(alpha);

      if (particle.isSparkle) {
        // Draw sparkle (4-pointed star)
        _drawSparkle(canvas, Offset(x, y), currentSize, paint, normalizedProgress * particle.rotationSpeed);
      } else {
        // Draw glowing circle
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset(x, y), currentSize, paint);

        // Inner bright core
        paint.color = Colors.white.withOpacity(alpha * 0.6);
        paint.maskFilter = null;
        canvas.drawCircle(Offset(x, y), currentSize * 0.4, paint);
      }
    }
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Paint paint, double rotation) {
    final path = Path();

    for (int i = 0; i < 4; i++) {
      final angle = rotation + (i * pi / 2);
      final outerX = center.dx + cos(angle) * size;
      final outerY = center.dy + sin(angle) * size;
      final innerAngle = angle + pi / 4;
      final innerX = center.dx + cos(innerAngle) * size * 0.3;
      final innerY = center.dy + sin(innerAngle) * size * 0.3;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ParticleExplosionPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A continuous rainbow particle stream effect
class RainbowParticleStream extends StatefulWidget {
  final bool isActive;
  final double intensity;

  const RainbowParticleStream({
    super.key,
    this.isActive = true,
    this.intensity = 1.0,
  });

  @override
  State<RainbowParticleStream> createState() => _RainbowParticleStreamState();
}

class _RainbowParticleStreamState extends State<RainbowParticleStream>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_StreamParticle> _particles = [];
  final Random _random = Random();

  static const List<Color> _rainbowColors = [
    Color(0xFFFF0000), // Red
    Color(0xFFFF7F00), // Orange
    Color(0xFFFFFF00), // Yellow
    Color(0xFF00FF00), // Green
    Color(0xFF0000FF), // Blue
    Color(0xFF4B0082), // Indigo
    Color(0xFF9400D3), // Violet
    AppColors.bansheeGreen,
    AppColors.primaryCyan,
    AppColors.primaryMagenta,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateParticles);

    if (widget.isActive) {
      _controller.repeat();
    }
  }

  void _updateParticles() {
    if (!widget.isActive) return;

    // Add new particles
    final spawnRate = (5 * widget.intensity).round();
    for (int i = 0; i < spawnRate; i++) {
      _particles.add(_StreamParticle(
        x: _random.nextDouble(),
        y: 1.0 + _random.nextDouble() * 0.1,
        vx: (_random.nextDouble() - 0.5) * 0.02,
        vy: -0.01 - _random.nextDouble() * 0.02,
        size: 2 + _random.nextDouble() * 4,
        color: _rainbowColors[_random.nextInt(_rainbowColors.length)],
        life: 1.0,
        decay: 0.01 + _random.nextDouble() * 0.02,
      ));
    }

    // Update existing particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= p.decay;

      // Add some wobble
      p.vx += (_random.nextDouble() - 0.5) * 0.002;

      if (p.life <= 0 || p.y < -0.1) {
        _particles.removeAt(i);
      }
    }

    setState(() {});
  }

  @override
  void didUpdateWidget(RainbowParticleStream oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RainbowStreamPainter(particles: _particles),
      ),
    );
  }
}

class _StreamParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  Color color;
  double life;
  double decay;

  _StreamParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.life,
    required this.decay,
  });
}

class _RainbowStreamPainter extends CustomPainter {
  final List<_StreamParticle> particles;

  _RainbowStreamPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final x = p.x * size.width;
      final y = p.y * size.height;

      final paint = Paint()
        ..color = p.color.withOpacity(p.life * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawCircle(Offset(x, y), p.size * p.life, paint);

      // Bright core
      paint.color = Colors.white.withOpacity(p.life * 0.5);
      paint.maskFilter = null;
      canvas.drawCircle(Offset(x, y), p.size * p.life * 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(_RainbowStreamPainter oldDelegate) => true;
}
