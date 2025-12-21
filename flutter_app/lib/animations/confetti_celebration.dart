import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

/// A celebratory confetti animation for achievements and personal bests
class ConfettiCelebration extends StatefulWidget {
  final bool isActive;
  final Duration duration;
  final VoidCallback? onComplete;

  const ConfettiCelebration({
    super.key,
    this.isActive = false,
    this.duration = const Duration(seconds: 4),
    this.onComplete,
  });

  @override
  State<ConfettiCelebration> createState() => _ConfettiCelebrationState();
}

class _ConfettiCelebrationState extends State<ConfettiCelebration>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_ConfettiPiece> _confetti = [];
  final Random _random = Random();

  static const List<Color> _confettiColors = [
    Color(0xFFFF6B6B), // Coral Red
    Color(0xFF4ECDC4), // Teal
    Color(0xFFFFE66D), // Sunny Yellow
    Color(0xFF95E1D3), // Mint
    Color(0xFFF38181), // Salmon
    Color(0xFFAA96DA), // Lavender
    Color(0xFFFCBAD3), // Pink
    Color(0xFFA8D8EA), // Sky Blue
    AppColors.bansheeGreen,
    AppColors.primaryCyan,
    AppColors.primaryMagenta,
    Colors.amber,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addListener(() {
        setState(() {});
      });

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
      }
    });

    if (widget.isActive) {
      _startCelebration();
    }
  }

  void _startCelebration() {
    _confetti.clear();
    _generateConfetti();
    _controller.forward(from: 0);

    // Trigger haptic celebration
    HapticService.instance.personalBestAchieved();
  }

  void _generateConfetti() {
    for (int i = 0; i < 150; i++) {
      final type = _ConfettiType.values[_random.nextInt(_ConfettiType.values.length)];
      _confetti.add(_ConfettiPiece(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        vx: (_random.nextDouble() - 0.5) * 0.3,
        vy: 0.2 + _random.nextDouble() * 0.4,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 8,
        size: 8 + _random.nextDouble() * 12,
        color: _confettiColors[_random.nextInt(_confettiColors.length)],
        type: type,
        delay: _random.nextDouble() * 0.3,
        wobbleSpeed: 2 + _random.nextDouble() * 3,
        wobbleAmount: 0.02 + _random.nextDouble() * 0.04,
      ));
    }
  }

  @override
  void didUpdateWidget(ConfettiCelebration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _startCelebration();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive && !_controller.isAnimating) {
      return const SizedBox.shrink();
    }

    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(
          confetti: _confetti,
          progress: _controller.value,
        ),
      ),
    );
  }
}

enum _ConfettiType { rectangle, circle, triangle, star, ribbon }

class _ConfettiPiece {
  double x;
  double y;
  double vx;
  double vy;
  double rotation;
  final double rotationSpeed;
  final double size;
  final Color color;
  final _ConfettiType type;
  final double delay;
  final double wobbleSpeed;
  final double wobbleAmount;

  _ConfettiPiece({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.type,
    required this.delay,
    required this.wobbleSpeed,
    required this.wobbleAmount,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> confetti;
  final double progress;

  _ConfettiPainter({
    required this.confetti,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in confetti) {
      // Apply delay
      final adjustedProgress = (progress - piece.delay).clamp(0.0, 1.0);
      if (adjustedProgress <= 0) continue;

      final normalizedProgress = adjustedProgress / (1 - piece.delay);

      // Calculate position with physics
      final gravity = normalizedProgress * normalizedProgress * 0.5;
      final wobble = sin(normalizedProgress * piece.wobbleSpeed * 2 * pi) * piece.wobbleAmount;

      final x = (piece.x + piece.vx * normalizedProgress + wobble) * size.width;
      final y = (piece.y + piece.vy * normalizedProgress + gravity) * size.height;

      // Fade out near bottom
      final alpha = (1 - (y / size.height - 0.7) / 0.3).clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      // Update rotation
      final rotation = piece.rotation + piece.rotationSpeed * normalizedProgress;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      final paint = Paint()
        ..color = piece.color.withOpacity(alpha)
        ..style = PaintingStyle.fill;

      switch (piece.type) {
        case _ConfettiType.rectangle:
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: piece.size,
              height: piece.size * 0.6,
            ),
            paint,
          );
          break;

        case _ConfettiType.circle:
          canvas.drawCircle(Offset.zero, piece.size * 0.4, paint);
          break;

        case _ConfettiType.triangle:
          final path = Path()
            ..moveTo(0, -piece.size * 0.5)
            ..lineTo(piece.size * 0.4, piece.size * 0.3)
            ..lineTo(-piece.size * 0.4, piece.size * 0.3)
            ..close();
          canvas.drawPath(path, paint);
          break;

        case _ConfettiType.star:
          _drawStar(canvas, piece.size * 0.5, paint);
          break;

        case _ConfettiType.ribbon:
          final path = Path();
          for (int i = 0; i < 4; i++) {
            final segment = i.toDouble() / 3;
            final segmentX = (segment - 0.5) * piece.size;
            final segmentY = sin(segment * 2 * pi + normalizedProgress * 4) * piece.size * 0.3;
            if (i == 0) {
              path.moveTo(segmentX, segmentY);
            } else {
              path.lineTo(segmentX, segmentY);
            }
          }
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 3;
          paint.strokeCap = StrokeCap.round;
          canvas.drawPath(path, paint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, double radius, Paint paint) {
    final path = Path();
    final innerRadius = radius * 0.4;

    for (int i = 0; i < 10; i++) {
      final angle = i * pi / 5 - pi / 2;
      final r = i.isEven ? radius : innerRadius;
      final x = cos(angle) * r;
      final y = sin(angle) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// A burst of sparkles that can be triggered at any position
class SparkleBurst extends StatefulWidget {
  final Offset position;
  final bool trigger;
  final int sparkleCount;
  final List<Color> colors;

  const SparkleBurst({
    super.key,
    required this.position,
    this.trigger = false,
    this.sparkleCount = 12,
    this.colors = const [
      Colors.amber,
      Colors.white,
      AppColors.bansheeGreen,
    ],
  });

  @override
  State<SparkleBurst> createState() => _SparkleBurstState();
}

class _SparkleBurstState extends State<SparkleBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Sparkle> _sparkles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() => setState(() {}));

    if (widget.trigger) {
      _burst();
    }
  }

  void _burst() {
    _sparkles.clear();
    for (int i = 0; i < widget.sparkleCount; i++) {
      final angle = (i / widget.sparkleCount) * 2 * pi + _random.nextDouble() * 0.2;
      _sparkles.add(_Sparkle(
        angle: angle,
        velocity: 0.5 + _random.nextDouble() * 0.5,
        size: 3 + _random.nextDouble() * 4,
        color: widget.colors[_random.nextInt(widget.colors.length)],
      ));
    }
    _controller.forward(from: 0);
    HapticService.instance.lightTap();
  }

  @override
  void didUpdateWidget(SparkleBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _burst();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.isAnimating && _sparkles.isEmpty) {
      return const SizedBox.shrink();
    }

    return CustomPaint(
      size: Size.infinite,
      painter: _SparkleBurstPainter(
        sparkles: _sparkles,
        position: widget.position,
        progress: _controller.value,
      ),
    );
  }
}

class _Sparkle {
  final double angle;
  final double velocity;
  final double size;
  final Color color;

  _Sparkle({
    required this.angle,
    required this.velocity,
    required this.size,
    required this.color,
  });
}

class _SparkleBurstPainter extends CustomPainter {
  final List<_Sparkle> sparkles;
  final Offset position;
  final double progress;

  _SparkleBurstPainter({
    required this.sparkles,
    required this.position,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final easedProgress = 1 - pow(1 - progress, 3);
    final alpha = (1 - progress).clamp(0.0, 1.0);

    for (final sparkle in sparkles) {
      final distance = easedProgress * 60 * sparkle.velocity;
      final x = position.dx + cos(sparkle.angle) * distance;
      final y = position.dy + sin(sparkle.angle) * distance;

      final paint = Paint()
        ..color = sparkle.color.withOpacity(alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      final currentSize = sparkle.size * (1 - progress * 0.5);

      // Draw sparkle
      canvas.drawCircle(Offset(x, y), currentSize, paint);

      // Bright core
      paint.color = Colors.white.withOpacity(alpha * 0.8);
      paint.maskFilter = null;
      canvas.drawCircle(Offset(x, y), currentSize * 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(_SparkleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
