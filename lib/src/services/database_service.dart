import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:banshee_run_app/src/rust/api/run_api.dart' as rust_api;

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  /// Initialize the database
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(directory.path, 'banshee_run.db');

      await rust_api.initDatabase(dbPath: dbPath);
      _isInitialized = true;
      debugPrint('Database initialized at: $dbPath');
    } catch (e) {
      debugPrint('Error initializing database: $e');
      rethrow;
    }
  }

  /// Create a new run
  Future<String> createRun() async {
    return await rust_api.createRun();
  }

  /// Get all runs
  Future<List<rust_api.RunSummaryDto>> getAllRuns() async {
    return await rust_api.getAllRuns();
  }

  /// Get a specific run by ID
  Future<rust_api.RunDetailDto?> getRun(String id) async {
    return await rust_api.getRun(id: id);
  }

  /// Add a GPS point to a run
  Future<double> addPointToRun(String runId, rust_api.GpsPointDto point) async {
    return await rust_api.addPointToRun(runId: runId, point: point);
  }

  /// Finish a run
  Future<rust_api.RunDetailDto> finishRun(String runId) async {
    return await rust_api.finishRun(runId: runId);
  }

  /// Delete a run
  Future<bool> deleteRun(String id) async {
    return await rust_api.deleteRun(id: id);
  }

  /// Get total run count
  Future<int> getRunCount() async {
    return (await rust_api.getRunCount()).toInt();
  }

  /// Get total distance (meters)
  Future<double> getTotalDistance() async {
    return await rust_api.getTotalDistance();
  }
}
