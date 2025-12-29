import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:banshee_run_app/src/services/database_service.dart';
import 'package:banshee_run_app/src/services/location_service.dart';
import 'package:banshee_run_app/src/services/foreground_task_service.dart';
import 'package:banshee_run_app/src/services/foreground_task_handler.dart';
import 'package:banshee_run_app/src/rust/api/run_api.dart' as rust_api;

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

enum RunStatus { idle, running, paused, finished }

class RunState {
  final RunStatus status;
  final String? runId;
  final int elapsedMs;
  final double distanceM;
  final double currentPaceSecPerKm;
  final List<Position> positions;
  final DateTime? startTime;
  final String? error;

  const RunState({
    this.status = RunStatus.idle,
    this.runId,
    this.elapsedMs = 0,
    this.distanceM = 0,
    this.currentPaceSecPerKm = 0,
    this.positions = const [],
    this.startTime,
    this.error,
  });

  RunState copyWith({
    RunStatus? status,
    String? runId,
    int? elapsedMs,
    double? distanceM,
    double? currentPaceSecPerKm,
    List<Position>? positions,
    DateTime? startTime,
    String? error,
  }) {
    return RunState(
      status: status ?? this.status,
      runId: runId ?? this.runId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      distanceM: distanceM ?? this.distanceM,
      currentPaceSecPerKm: currentPaceSecPerKm ?? this.currentPaceSecPerKm,
      positions: positions ?? this.positions,
      startTime: startTime ?? this.startTime,
      error: error,
    );
  }

  double get distanceKm => distanceM / 1000;

  String get durationFormatted {
    final totalSeconds = elapsedMs ~/ 1000;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString()}:${seconds.toString().padLeft(2, '0')}';
  }
}

class RunNotifier extends StateNotifier<RunState> {
  final DatabaseService _databaseService;
  final LocationService _locationService;
  Timer? _timer;
  StreamSubscription<Position>? _locationSubscription;

  RunNotifier(this._databaseService, this._locationService)
    : super(const RunState());

  Future<void> startRun() async {
    try {
      // Create run in database
      final runId = await _databaseService.createRun();

      // Start location tracking
      await _locationService.startTracking();

      state = RunState(
        status: RunStatus.running,
        runId: runId,
        startTime: DateTime.now(),
      );

      // Start timer
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (state.status == RunStatus.running) {
          state = state.copyWith(elapsedMs: state.elapsedMs + 1000);
        }
      });

      // Listen to location updates
      _locationSubscription = _locationService.positionStream.listen(
        _onLocationUpdate,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to start run: $e');
    }
  }

  void _onLocationUpdate(Position position) async {
    if (state.status != RunStatus.running) return;

    final positions = [...state.positions, position];

    // Calculate distance
    double distance = state.distanceM;
    if (positions.length >= 2) {
      final prev = positions[positions.length - 2];
      final current = positions[positions.length - 1];
      distance += _locationService.calculateDistance(
        prev.latitude,
        prev.longitude,
        current.latitude,
        current.longitude,
      );
    }

    // Calculate pace
    double pace = 0;
    if (distance > 0 && state.elapsedMs > 0) {
      pace = (state.elapsedMs / 1000) / (distance / 1000);
    }

    // Add point to database
    if (state.runId != null) {
      try {
        await _databaseService.addPointToRun(
          state.runId!,
          rust_api.GpsPointDto(
            lat: position.latitude,
            lon: position.longitude,
            altitude: position.altitude,
            timestampMs: DateTime.now().millisecondsSinceEpoch,
            accuracy: position.accuracy,
            speed: position.speed,
          ),
        );
      } catch (e) {
        // Continue even if db write fails
      }
    }

    state = state.copyWith(
      positions: positions,
      distanceM: distance,
      currentPaceSecPerKm: pace,
    );
  }

  void pauseRun() {
    state = state.copyWith(status: RunStatus.paused);
  }

  void resumeRun() {
    state = state.copyWith(status: RunStatus.running);
  }

  Future<void> finishRun() async {
    _timer?.cancel();
    await _locationSubscription?.cancel();
    await _locationService.stopTracking();

    if (state.runId != null) {
      try {
        await _databaseService.finishRun(state.runId!);
      } catch (e) {
        // Continue even if db write fails
      }
    }

    state = state.copyWith(status: RunStatus.finished);
  }

  void reset() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    state = const RunState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
}

final runNotifierProvider = StateNotifierProvider<RunNotifier, RunState>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  final locationService = LocationService();
  return RunNotifier(databaseService, locationService);
});

// Provider for run history
final runHistoryProvider = FutureProvider<List<rust_api.RunSummaryDto>>((
  ref,
) async {
  final databaseService = ref.watch(databaseServiceProvider);
  return await databaseService.getAllRuns();
});

// Provider for total stats
final totalStatsProvider =
    FutureProvider<({int runCount, double totalDistance})>((ref) async {
      final databaseService = ref.watch(databaseServiceProvider);
      final count = await databaseService.getRunCount();
      final distance = await databaseService.getTotalDistance();
      return (runCount: count, totalDistance: distance);
    });

// ============================================================================
// Foreground Run Provider (for background-safe tracking)
// ============================================================================

final foregroundTaskServiceProvider = Provider<ForegroundTaskService>((ref) {
  return ForegroundTaskService();
});

enum ForegroundRunStatus { idle, running, paused, finishing }

class ForegroundRunState {
  final ForegroundRunStatus status;
  final String? runId;
  final int elapsedMs;
  final double distanceM;
  final double? currentPaceSecPerKm;
  final LatLng? currentPosition;
  final List<LatLng> route;
  final int startTimeMs;
  final String? error;

  const ForegroundRunState({
    this.status = ForegroundRunStatus.idle,
    this.runId,
    this.elapsedMs = 0,
    this.distanceM = 0,
    this.currentPaceSecPerKm,
    this.currentPosition,
    this.route = const [],
    this.startTimeMs = 0,
    this.error,
  });

  ForegroundRunState copyWith({
    ForegroundRunStatus? status,
    String? runId,
    int? elapsedMs,
    double? distanceM,
    double? currentPaceSecPerKm,
    LatLng? currentPosition,
    List<LatLng>? route,
    int? startTimeMs,
    String? error,
  }) {
    return ForegroundRunState(
      status: status ?? this.status,
      runId: runId ?? this.runId,
      elapsedMs: elapsedMs ?? this.elapsedMs,
      distanceM: distanceM ?? this.distanceM,
      currentPaceSecPerKm: currentPaceSecPerKm ?? this.currentPaceSecPerKm,
      currentPosition: currentPosition ?? this.currentPosition,
      route: route ?? this.route,
      startTimeMs: startTimeMs ?? this.startTimeMs,
      error: error,
    );
  }

  bool get isActive =>
      status == ForegroundRunStatus.running ||
      status == ForegroundRunStatus.paused;
}

class ForegroundRunNotifier extends StateNotifier<ForegroundRunState> {
  final ForegroundTaskService _taskService;
  final DatabaseService _databaseService;
  StreamSubscription<Map<String, dynamic>>? _dataSubscription;

  ForegroundRunNotifier(this._taskService, this._databaseService)
    : super(const ForegroundRunState());

  Future<void> startRun() async {
    try {
      // Create run in database first
      final runId = await _databaseService.createRun();
      final startTimeMs = DateTime.now().millisecondsSinceEpoch;

      // Start foreground task
      final success = await _taskService.startTask();
      if (!success) {
        state = state.copyWith(error: 'Failed to start foreground service');
        return;
      }

      // Listen to data from task handler
      _dataSubscription = _taskService.dataStream.listen(_onDataReceived);

      // Send start command to task handler
      _taskService.sendCommand(RunTaskCommand.start, runId: runId);

      state = ForegroundRunState(
        status: ForegroundRunStatus.running,
        runId: runId,
        startTimeMs: startTimeMs,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to start run: $e');
    }
  }

  void _onDataReceived(Map<String, dynamic> data) async {
    // Handle GPS point data - save to database
    if (data['type'] == 'gps_point') {
      await _handleGpsPoint(data);
      return;
    }

    // Handle status update from task handler
    if (data['type'] == 'status') {
      LatLng? position;
      final lat = data['lat'] as double?;
      final lon = data['lon'] as double?;
      if (lat != null && lon != null) {
        position = LatLng(lat, lon);
      }

      final newRoute = position != null && position != state.currentPosition
          ? [...state.route, position]
          : state.route;

      final isPaused = data['isPaused'] as bool? ?? false;
      final isRunning = data['isRunning'] as bool? ?? false;

      state = state.copyWith(
        elapsedMs: data['elapsedMs'] as int? ?? state.elapsedMs,
        distanceM: (data['distanceM'] as num?)?.toDouble() ?? state.distanceM,
        currentPaceSecPerKm: data['currentPaceSecPerKm'] as double?,
        currentPosition: position ?? state.currentPosition,
        route: newRoute,
        status: isPaused
            ? ForegroundRunStatus.paused
            : (isRunning ? ForegroundRunStatus.running : state.status),
      );
    }
  }

  Future<void> _handleGpsPoint(Map<String, dynamic> data) async {
    final runId = data['runId'] as String?;
    if (runId == null) return;

    try {
      await _databaseService.addPointToRun(
        runId,
        rust_api.GpsPointDto(
          lat: data['lat'] as double,
          lon: data['lon'] as double,
          altitude: data['altitude'] as double?,
          timestampMs: data['timestampMs'] as int,
          accuracy: data['accuracy'] as double?,
          speed: data['speed'] as double?,
        ),
      );
    } catch (e) {
      // Log but don't fail - we want tracking to continue
      debugPrint('Failed to save GPS point: $e');
    }
  }

  void pauseRun() {
    _taskService.sendCommand(RunTaskCommand.pause);
    state = state.copyWith(status: ForegroundRunStatus.paused);
  }

  void resumeRun() {
    _taskService.sendCommand(RunTaskCommand.resume);
    state = state.copyWith(status: ForegroundRunStatus.running);
  }

  Future<ForegroundRunState> finishRun() async {
    state = state.copyWith(status: ForegroundRunStatus.finishing);

    // Stop the task handler
    _taskService.sendCommand(RunTaskCommand.stop);

    // Cancel data subscription
    await _dataSubscription?.cancel();
    _dataSubscription = null;

    // Stop foreground service
    await _taskService.stopTask();

    // Finish run in database
    if (state.runId != null) {
      try {
        await _databaseService.finishRun(state.runId!);
      } catch (e) {
        // Continue even if db write fails
      }
    }

    // Return final state for navigation to complete screen
    final finalState = state;

    // Reset state
    state = const ForegroundRunState();

    return finalState;
  }

  Future<void> cancelRun() async {
    _taskService.sendCommand(RunTaskCommand.stop);
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _taskService.stopTask();

    // Delete the incomplete run from database
    if (state.runId != null) {
      await _databaseService.deleteRun(state.runId!);
    }

    state = const ForegroundRunState();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    super.dispose();
  }
}

final foregroundRunProvider =
    StateNotifierProvider<ForegroundRunNotifier, ForegroundRunState>((ref) {
      final taskService = ref.watch(foregroundTaskServiceProvider);
      final databaseService = ref.watch(databaseServiceProvider);
      return ForegroundRunNotifier(taskService, databaseService);
    });
