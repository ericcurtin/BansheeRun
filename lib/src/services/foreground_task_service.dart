import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:banshee_run_app/src/services/foreground_task_handler.dart';

class ForegroundTaskService {
  static final ForegroundTaskService _instance =
      ForegroundTaskService._internal();
  factory ForegroundTaskService() => _instance;
  ForegroundTaskService._internal();

  final _dataController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get dataStream => _dataController.stream;

  bool _isInitialized = false;
  Function(Object)? _dataCallback;

  /// Initialize the foreground task service
  Future<void> init() async {
    if (_isInitialized) return;

    _initForegroundTask();
    _isInitialized = true;
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'banshee_run_foreground',
        channelName: 'BansheeRun Active Run',
        channelDescription: 'Shows when a run is in progress',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
        playSound: false,
        showWhen: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), // 1 second
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// Request necessary permissions
  Future<bool> requestPermissions() async {
    // Notification permission (Android 13+)
    final notificationStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Battery optimization
    final isIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    if (!isIgnoring) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    return true;
  }

  /// Start the foreground task for a run
  Future<bool> startTask() async {
    await requestPermissions();

    // Set up data callback
    _dataCallback = (data) {
      if (data is Map<String, dynamic>) {
        _dataController.add(data);
      }
    };
    FlutterForegroundTask.addTaskDataCallback(_dataCallback!);

    // Start or restart the service
    final isRunning = await FlutterForegroundTask.isRunningService;
    ServiceRequestResult result;
    if (isRunning) {
      result = await FlutterForegroundTask.restartService();
    } else {
      result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'BansheeRun',
        notificationText: 'Starting run...',
        callback: startCallback,
      );
    }
    return result is ServiceRequestSuccess;
  }

  /// Stop the foreground task
  Future<bool> stopTask() async {
    if (_dataCallback != null) {
      FlutterForegroundTask.removeTaskDataCallback(_dataCallback!);
      _dataCallback = null;
    }
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  /// Send command to the task handler
  void sendCommand(RunTaskCommand command, {String? runId}) {
    final message = {'command': command.name, 'runId': runId};
    FlutterForegroundTask.sendDataToTask(message);
  }

  /// Check if task is running
  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  void dispose() {
    _dataController.close();
  }
}
