import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// Service for providing haptic feedback throughout the app
class HapticService {
  static HapticService? _instance;
  bool _hasVibrator = false;
  bool _hasAmplitudeControl = false;

  HapticService._();

  static HapticService get instance {
    _instance ??= HapticService._();
    return _instance!;
  }

  /// Initialize the haptic service and check device capabilities
  Future<void> initialize() async {
    _hasVibrator = await Vibration.hasVibrator() ?? false;
    _hasAmplitudeControl = await Vibration.hasAmplitudeControl() ?? false;
  }

  /// Light tap - for button presses, selections
  Future<void> lightTap() async {
    await HapticFeedback.lightImpact();
  }

  /// Medium tap - for confirmations, toggles
  Future<void> mediumTap() async {
    await HapticFeedback.mediumImpact();
  }

  /// Heavy tap - for important actions, errors
  Future<void> heavyTap() async {
    await HapticFeedback.heavyImpact();
  }

  /// Selection changed - for scrolling, picker changes
  Future<void> selectionClick() async {
    await HapticFeedback.selectionClick();
  }

  /// Success feedback - positive action completed
  Future<void> success() async {
    if (_hasVibrator) {
      if (_hasAmplitudeControl) {
        await Vibration.vibrate(duration: 50, amplitude: 128);
        await Future.delayed(const Duration(milliseconds: 100));
        await Vibration.vibrate(duration: 100, amplitude: 200);
      } else {
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.heavyImpact();
      }
    } else {
      await HapticFeedback.mediumImpact();
    }
  }

  /// Warning feedback - caution needed
  Future<void> warning() async {
    if (_hasVibrator) {
      await Vibration.vibrate(pattern: [0, 100, 50, 100], intensities: [0, 128, 0, 200]);
    } else {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    }
  }

  /// Error feedback - something went wrong
  Future<void> error() async {
    if (_hasVibrator) {
      await Vibration.vibrate(pattern: [0, 100, 50, 100, 50, 200], intensities: [0, 200, 0, 255, 0, 255]);
    } else {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Banshee approaching - escalating intensity
  Future<void> bansheeApproaching(double intensity) async {
    if (!_hasVibrator) {
      await HapticFeedback.heavyImpact();
      return;
    }

    // Intensity from 0.0 to 1.0
    final clampedIntensity = intensity.clamp(0.0, 1.0);
    final amplitude = (clampedIntensity * 255).round();
    final duration = (50 + (clampedIntensity * 150)).round();

    if (_hasAmplitudeControl) {
      await Vibration.vibrate(duration: duration, amplitude: amplitude);
    } else {
      await HapticFeedback.heavyImpact();
    }
  }

  /// Heartbeat pattern - for intense moments
  Future<void> heartbeat() async {
    if (_hasVibrator) {
      // Lub-dub pattern
      await Vibration.vibrate(
        pattern: [0, 80, 100, 60, 400],
        intensities: [0, 255, 0, 200, 0],
      );
    } else {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.mediumImpact();
    }
  }

  /// Activity started feedback
  Future<void> activityStarted() async {
    if (_hasVibrator && _hasAmplitudeControl) {
      // Rising pattern
      await Vibration.vibrate(duration: 50, amplitude: 64);
      await Future.delayed(const Duration(milliseconds: 75));
      await Vibration.vibrate(duration: 50, amplitude: 128);
      await Future.delayed(const Duration(milliseconds: 75));
      await Vibration.vibrate(duration: 100, amplitude: 255);
    } else {
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Activity stopped feedback
  Future<void> activityStopped() async {
    if (_hasVibrator && _hasAmplitudeControl) {
      // Falling pattern
      await Vibration.vibrate(duration: 100, amplitude: 255);
      await Future.delayed(const Duration(milliseconds: 75));
      await Vibration.vibrate(duration: 50, amplitude: 128);
      await Future.delayed(const Duration(milliseconds: 75));
      await Vibration.vibrate(duration: 50, amplitude: 64);
    } else {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 75));
      await HapticFeedback.lightImpact();
    }
  }

  /// Personal best achieved!
  Future<void> personalBestAchieved() async {
    if (_hasVibrator) {
      // Celebratory pattern
      await Vibration.vibrate(
        pattern: [0, 100, 50, 100, 50, 100, 100, 200],
        intensities: [0, 200, 0, 200, 0, 200, 0, 255],
      );
    } else {
      for (int i = 0; i < 3; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
    }
  }

  /// Pace change notification
  Future<void> paceChange(bool gettingFaster) async {
    if (gettingFaster) {
      // Quick double tap for speeding up
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 50));
      await HapticFeedback.lightImpact();
    } else {
      // Single heavy for slowing down
      await HapticFeedback.heavyImpact();
    }
  }

  /// Cancel any ongoing vibration
  Future<void> cancel() async {
    if (_hasVibrator) {
      await Vibration.cancel();
    }
  }
}
