import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:banshee_run_app/src/rust/frb_generated.dart';
import 'package:banshee_run_app/src/services/database_service.dart';
import 'package:banshee_run_app/src/services/foreground_task_service.dart';
import 'package:banshee_run_app/src/app.dart';
import 'package:banshee_run_app/src/services/tile_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize communication port for foreground task (must be early)
  FlutterForegroundTask.initCommunicationPort();

  await RustLib.init();
  await DatabaseService().init();
  await TileCacheService.instance.init();
  await ForegroundTaskService().init();

  runApp(const ProviderScope(child: BansheeRunApp()));
}
