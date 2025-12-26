import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:banshee_run_app/src/rust/frb_generated.dart';
import 'package:banshee_run_app/src/services/database_service.dart';
import 'package:banshee_run_app/src/app.dart';
import 'package:banshee_run_app/src/services/tile_cache_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await DatabaseService().init();
  await TileCacheService.instance.init();
  runApp(const ProviderScope(child: BansheeRunApp()));
}
