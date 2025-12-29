import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';

/// Commands from UI to task handler
enum RunTaskCommand { start, pause, resume, stop }

/// The TaskHandler that runs in the foreground service isolate
@pragma('vm:entry-point')
class RunTaskHandler extends TaskHandler {
  // Run state
  String? _runId;
  int _elapsedMs = 0;
  double _distanceM = 0.0;
  double? _lastLat;
  double? _lastLon;
  bool _isRunning = false;
  bool _isPaused = false;

  // Location tracking
  StreamSubscription<Position>? _locationSubscription;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _startLocationStream();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    // This fires every second (configured interval)
    if (_isRunning && !_isPaused) {
      _elapsedMs += 1000;
    }

    // Calculate pace
    double? pace;
    if (_distanceM > 0 && _elapsedMs > 0) {
      pace = (_elapsedMs / 1000) / (_distanceM / 1000);
    }

    // Send status update to UI
    final data = {
      'type': 'status',
      'elapsedMs': _elapsedMs,
      'distanceM': _distanceM,
      'currentPaceSecPerKm': pace,
      'lat': _lastLat,
      'lon': _lastLon,
      'runId': _runId,
      'isRunning': _isRunning,
      'isPaused': _isPaused,
    };
    FlutterForegroundTask.sendDataToMain(data);

    // Update notification
    await _updateNotification();
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      _handleCommand(data);
    }
  }

  Future<void> _startLocationStream() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onLocationUpdate);
  }

  void _onLocationUpdate(Position position) {
    if (!_isRunning || _isPaused) return;

    // Calculate distance from previous position
    if (_lastLat != null && _lastLon != null) {
      final distance = Geolocator.distanceBetween(
        _lastLat!,
        _lastLon!,
        position.latitude,
        position.longitude,
      );
      _distanceM += distance;
    }

    _lastLat = position.latitude;
    _lastLon = position.longitude;

    // Send GPS point data for database persistence
    final gpsData = {
      'type': 'gps_point',
      'runId': _runId,
      'lat': position.latitude,
      'lon': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'timestampMs': DateTime.now().millisecondsSinceEpoch,
      'distanceM': _distanceM,
    };
    FlutterForegroundTask.sendDataToMain(gpsData);
  }

  void _handleCommand(Map<String, dynamic> data) {
    final commandStr = data['command'] as String?;
    if (commandStr == null) return;

    final command = RunTaskCommand.values.firstWhere(
      (e) => e.name == commandStr,
      orElse: () => RunTaskCommand.stop,
    );

    switch (command) {
      case RunTaskCommand.start:
        _runId = data['runId'] as String?;
        _elapsedMs = 0;
        _distanceM = 0.0;
        _lastLat = null;
        _lastLon = null;
        _isRunning = true;
        _isPaused = false;
        break;
      case RunTaskCommand.pause:
        _isPaused = true;
        break;
      case RunTaskCommand.resume:
        _isPaused = false;
        break;
      case RunTaskCommand.stop:
        _isRunning = false;
        _isPaused = false;
        break;
    }
  }

  Future<void> _updateNotification() async {
    if (!_isRunning) return;

    final duration = _formatDuration(_elapsedMs);
    final distance = _formatDistance(_distanceM);
    final paceStr = _distanceM > 0 && _elapsedMs > 0
        ? _formatPace((_elapsedMs / 1000) / (_distanceM / 1000))
        : '--:--';

    final title = _isPaused ? 'Run Paused' : 'Running';
    final body = '$duration | $distance | $paceStr/km';

    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: body,
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _formatPace(double paceSecPerKm) {
    if (paceSecPerKm <= 0 || paceSecPerKm.isNaN || paceSecPerKm.isInfinite) {
      return '--:--';
    }
    final totalSeconds = paceSecPerKm.round();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Callback entry point - must be top-level
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RunTaskHandler());
}
