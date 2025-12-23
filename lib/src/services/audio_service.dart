import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum AudioCue { start, ahead, behind, milestone, finish }

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final AudioPlayer _player = AudioPlayer();
  bool _isEnabled = true;
  bool _isInitialized = false;

  bool get isEnabled => _isEnabled;

  /// Initialize the audio service
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
    }
  }

  /// Enable or disable audio
  void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  /// Play an audio cue
  Future<void> playCue(AudioCue cue) async {
    if (!_isEnabled || !_isInitialized) return;

    try {
      final assetPath = _getAssetPath(cue);
      await _player.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('Error playing audio cue: $e');
    }
  }

  /// Play a tone at a specific frequency (for simple feedback)
  Future<void> playTone({
    required double frequency,
    Duration duration = const Duration(milliseconds: 200),
  }) async {
    if (!_isEnabled) return;

    // Note: audioplayers doesn't support tone generation directly
    // For simple tones, we'll use pre-recorded audio files
    // This is a placeholder for actual tone playback
    debugPrint(
      'Playing tone at ${frequency}Hz for ${duration.inMilliseconds}ms',
    );
  }

  /// Play ahead tone (higher pitch)
  Future<void> playAheadTone() async {
    await playCue(AudioCue.ahead);
  }

  /// Play behind tone (lower pitch)
  Future<void> playBehindTone() async {
    await playCue(AudioCue.behind);
  }

  /// Play milestone tone
  Future<void> playMilestoneTone() async {
    await playCue(AudioCue.milestone);
  }

  /// Play start beep
  Future<void> playStartTone() async {
    await playCue(AudioCue.start);
  }

  /// Play finish tone
  Future<void> playFinishTone() async {
    await playCue(AudioCue.finish);
  }

  String _getAssetPath(AudioCue cue) {
    switch (cue) {
      case AudioCue.start:
        return 'audio/start.wav';
      case AudioCue.ahead:
        return 'audio/ahead.wav';
      case AudioCue.behind:
        return 'audio/behind.wav';
      case AudioCue.milestone:
        return 'audio/milestone.wav';
      case AudioCue.finish:
        return 'audio/finish.wav';
    }
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
  }
}
