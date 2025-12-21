import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

/// A button with animated glowing ripple effects
class GlowingRippleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? glowColor;
  final double borderRadius;
  final EdgeInsets padding;
  final Gradient? gradient;

  const GlowingRippleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.glowColor,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
    this.gradient,
  });

  @override
  State<GlowingRippleButton> createState() => _GlowingRippleButtonState();
}

class _GlowingRippleButtonState extends State<GlowingRippleButton>
    with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _glowController;
  late Animation<double> _rippleAnimation;
  Offset? _tapPosition;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rippleAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
      _tapPosition = details.localPosition;
    });
    HapticService.instance.lightTap();
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _rippleController.forward(from: 0);
    widget.onTap();
    HapticService.instance.mediumTap();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.glowColor ?? AppColors.primaryCyan;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rippleController, _glowController]),
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                gradient: widget.gradient ?? LinearGradient(
                  colors: [color, color.withOpacity(0.8)],
                ),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3 + _glowController.value * 0.2),
                    blurRadius: 12 + _glowController.value * 8,
                    spreadRadius: _glowController.value * 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                child: Stack(
                  children: [
                    // Ripple effect
                    if (_tapPosition != null)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RipplePainter(
                            center: _tapPosition!,
                            progress: _rippleAnimation.value,
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    // Content
                    widget.child,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  final Offset center;
  final double progress;
  final Color color;

  _RipplePainter({
    required this.center,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = sqrt(pow(size.width, 2) + pow(size.height, 2));
    final radius = maxRadius * progress;
    final alpha = (1 - progress).clamp(0.0, 1.0);

    final paint = Paint()
      ..color = color.withOpacity(alpha * 0.5)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Animated wave border effect
class WaveBorderContainer extends StatefulWidget {
  final Widget child;
  final Color color;
  final double borderRadius;

  const WaveBorderContainer({
    super.key,
    required this.child,
    this.color = AppColors.primaryCyan,
    this.borderRadius = 20,
  });

  @override
  State<WaveBorderContainer> createState() => _WaveBorderContainerState();
}

class _WaveBorderContainerState extends State<WaveBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
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
        return CustomPaint(
          painter: _WaveBorderPainter(
            progress: _controller.value,
            color: widget.color,
            borderRadius: widget.borderRadius,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _WaveBorderPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double borderRadius;

  _WaveBorderPainter({
    required this.progress,
    required this.color,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress * 2 * pi,
        endAngle: progress * 2 * pi + 2 * pi,
        colors: [
          color,
          color.withOpacity(0.5),
          Colors.transparent,
          Colors.transparent,
          color.withOpacity(0.5),
          color,
        ],
        stops: const [0.0, 0.1, 0.3, 0.7, 0.9, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    canvas.drawRRect(rect, paint);
  }

  @override
  bool shouldRepaint(_WaveBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Pulsing glow effect around a widget
class PulsingGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final double maxBlur;
  final Duration duration;

  const PulsingGlow({
    super.key,
    required this.child,
    this.color = AppColors.bansheeGreen,
    this.maxBlur = 20,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulsingGlow> createState() => _PulsingGlowState();
}

class _PulsingGlowState extends State<PulsingGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.3 + _controller.value * 0.3),
                blurRadius: widget.maxBlur * (0.5 + _controller.value * 0.5),
                spreadRadius: _controller.value * 5,
              ),
            ],
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// Animated neon border
class NeonBorder extends StatefulWidget {
  final Widget child;
  final List<Color> colors;
  final double borderRadius;
  final double strokeWidth;
  final Duration duration;

  const NeonBorder({
    super.key,
    required this.child,
    this.colors = const [
      AppColors.primaryCyan,
      AppColors.primaryMagenta,
      AppColors.primaryPurple,
      AppColors.bansheeGreen,
    ],
    this.borderRadius = 16,
    this.strokeWidth = 3,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<NeonBorder> createState() => _NeonBorderState();
}

class _NeonBorderState extends State<NeonBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
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
        return CustomPaint(
          painter: _NeonBorderPainter(
            progress: _controller.value,
            colors: widget.colors,
            borderRadius: widget.borderRadius,
            strokeWidth: widget.strokeWidth,
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.strokeWidth),
            child: widget.child,
          ),
        );
      },
    );
  }
}

class _NeonBorderPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double borderRadius;
  final double strokeWidth;

  _NeonBorderPainter({
    required this.progress,
    required this.colors,
    required this.borderRadius,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // Background glow
    final glowPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress * 2 * pi,
        colors: colors + [colors.first],
      ).createShader(rect)
      ..strokeWidth = strokeWidth * 3
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawRRect(rrect, glowPaint);

    // Main border
    final borderPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: progress * 2 * pi,
        colors: colors + [colors.first],
      ).createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(_NeonBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Floating animation wrapper
class FloatingWidget extends StatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration duration;

  const FloatingWidget({
    super.key,
    required this.child,
    this.amplitude = 10,
    this.duration = const Duration(seconds: 2),
  });

  @override
  State<FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
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
        return Transform.translate(
          offset: Offset(0, sin(_controller.value * pi) * widget.amplitude),
          child: widget.child,
        );
      },
    );
  }
}
