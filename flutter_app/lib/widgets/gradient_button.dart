import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../services/haptic_service.dart';

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final Gradient? gradient;
  final IconData? icon;
  final bool isLoading;
  final bool isLarge;
  final double? width;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.gradient,
    this.icon,
    this.isLoading = false,
    this.isLarge = false,
    this.width,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buttonGradient = widget.gradient ?? AppColors.primaryGradient;

    return GestureDetector(
      onTapDown: (_) {
        if (!widget.isLoading) {
          setState(() => _isPressed = true);
          HapticService.instance.lightTap();
        }
      },
      onTapUp: (_) {
        if (!widget.isLoading) {
          setState(() => _isPressed = false);
          widget.onPressed();
          HapticService.instance.mediumTap();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        width: widget.width,
        transform: Matrix4.identity()
          ..scale(_isPressed ? 0.95 : 1.0),
        child: AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: widget.isLarge ? 32 : 24,
                vertical: widget.isLarge ? 18 : 14,
              ),
              decoration: BoxDecoration(
                gradient: buttonGradient,
                borderRadius: BorderRadius.circular(widget.isLarge ? 20 : 16),
                boxShadow: [
                  BoxShadow(
                    color: (buttonGradient.colors.first).withOpacity(0.4),
                    blurRadius: _isPressed ? 8 : 16,
                    offset: Offset(0, _isPressed ? 2 : 6),
                    spreadRadius: _isPressed ? -2 : 0,
                  ),
                  BoxShadow(
                    color: (buttonGradient.colors.last).withOpacity(0.3),
                    blurRadius: _isPressed ? 12 : 24,
                    offset: Offset(0, _isPressed ? 4 : 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Shimmer overlay
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(widget.isLarge ? 20 : 16),
                      child: ShaderMask(
                        shaderCallback: (bounds) {
                          return LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withOpacity(0.3),
                              Colors.transparent,
                            ],
                            stops: [
                              (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                              _shimmerController.value,
                              (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                            ],
                            transform: GradientRotation(0.5),
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.srcIn,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(widget.isLarge ? 20 : 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Content
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.isLoading)
                        SizedBox(
                          width: widget.isLarge ? 24 : 20,
                          height: widget.isLarge ? 24 : 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.darkBackground,
                            ),
                          ),
                        )
                      else if (widget.icon != null)
                        Icon(
                          widget.icon,
                          color: AppColors.darkBackground,
                          size: widget.isLarge ? 24 : 20,
                        ),
                      if ((widget.icon != null || widget.isLoading) && widget.text.isNotEmpty)
                        SizedBox(width: widget.isLarge ? 12 : 8),
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: AppColors.darkBackground,
                          fontSize: widget.isLarge ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class PulsingStartButton extends StatefulWidget {
  final bool isRunning;
  final VoidCallback onPressed;

  const PulsingStartButton({
    super.key,
    required this.isRunning,
    required this.onPressed,
  });

  @override
  State<PulsingStartButton> createState() => _PulsingStartButtonState();
}

class _PulsingStartButtonState extends State<PulsingStartButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.isRunning) {
          HapticService.instance.activityStopped();
        } else {
          HapticService.instance.activityStarted();
        }
        widget.onPressed();
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _rotationController]),
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          final rotationValue = _rotationController.value;

          return Container(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer rotating ring
                Transform.rotate(
                  angle: rotationValue * 2 * 3.14159,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: widget.isRunning
                            ? [
                                AppColors.behindRed,
                                AppColors.behindRed.withOpacity(0.3),
                                AppColors.behindRed,
                              ]
                            : [
                                AppColors.primaryCyan,
                                AppColors.primaryMagenta,
                                AppColors.primaryPurple,
                                AppColors.primaryCyan,
                              ],
                      ),
                    ),
                  ),
                ),
                // Pulsing glow
                Container(
                  width: 100 + pulseValue * 10,
                  height: 100 + pulseValue * 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.isRunning
                                ? AppColors.behindRed
                                : AppColors.primaryCyan)
                            .withOpacity(0.4 + pulseValue * 0.3),
                        blurRadius: 20 + pulseValue * 15,
                        spreadRadius: pulseValue * 8,
                      ),
                    ],
                  ),
                ),
                // Inner button
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: widget.isRunning
                          ? [
                              AppColors.behindRed,
                              AppColors.behindRed.withOpacity(0.7),
                            ]
                          : [
                              AppColors.primaryCyan,
                              AppColors.primaryMagenta,
                            ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.darkBackground.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      widget.isRunning ? Icons.stop : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    )
                        .animate(
                          target: widget.isRunning ? 1 : 0,
                        )
                        .scaleXY(
                          begin: 1,
                          end: 0.9,
                          duration: 300.ms,
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
