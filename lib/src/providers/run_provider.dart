import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:banshee_run_app/src/services/database_service.dart';
import 'package:banshee_run_app/src/services/location_service.dart';
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
