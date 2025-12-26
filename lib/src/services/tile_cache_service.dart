import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:dio_cache_interceptor_file_store/dio_cache_interceptor_file_store.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Service for managing map tile caching
class TileCacheService {
  static TileCacheService? _instance;
  static TileCacheService get instance => _instance ??= TileCacheService._();

  TileCacheService._();

  Dio? _dio;
  CacheStore? _cacheStore;
  String? _cacheDirectory;
  bool _isInitialized = false;

  /// Initialize the cache service
  Future<void> init() async {
    if (_isInitialized) return;

    final appDir = await getApplicationDocumentsDirectory();
    _cacheDirectory = p.join(appDir.path, 'map_tile_cache');

    // Ensure cache directory exists
    final cacheDir = Directory(_cacheDirectory!);
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    _cacheStore = FileCacheStore(_cacheDirectory!);

    final cacheOptions = CacheOptions(
      store: _cacheStore!,
      policy: CachePolicy.forceCache,
      hitCacheOnErrorExcept: [401, 403, 404],
      maxStale: const Duration(days: 30),
      priority: CachePriority.normal,
    );

    _dio = Dio()..interceptors.add(DioCacheInterceptor(options: cacheOptions));

    _isInitialized = true;
  }

  /// Get a tile provider that uses cached tiles
  TileProvider getTileProvider() {
    if (!_isInitialized || _dio == null) {
      // Return default network provider if not initialized
      return NetworkTileProvider();
    }
    return _CachedTileProvider(_dio!);
  }

  /// Clear all cached map tiles
  Future<void> clearCache() async {
    if (_cacheDirectory == null) return;

    final cacheDir = Directory(_cacheDirectory!);
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create(recursive: true);
    }

    // Reinitialize the cache store
    _cacheStore = FileCacheStore(_cacheDirectory!);

    final cacheOptions = CacheOptions(
      store: _cacheStore!,
      policy: CachePolicy.forceCache,
      hitCacheOnErrorExcept: [401, 403, 404],
      maxStale: const Duration(days: 30),
      priority: CachePriority.normal,
    );

    _dio = Dio()..interceptors.add(DioCacheInterceptor(options: cacheOptions));
  }

  /// Get the cache size in bytes
  Future<int> getCacheSize() async {
    if (_cacheDirectory == null) return 0;

    final cacheDir = Directory(_cacheDirectory!);
    if (!await cacheDir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in cacheDir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  /// Format cache size for display
  String formatCacheSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Custom tile provider that uses Dio with caching
class _CachedTileProvider extends TileProvider {
  final Dio _dio;

  _CachedTileProvider(this._dio);

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return _DioImageProvider(url, _dio);
  }
}

/// Custom image provider that fetches tiles using Dio (with caching)
class _DioImageProvider extends ImageProvider<_DioImageProvider> {
  final String url;
  final Dio dio;

  _DioImageProvider(this.url, this.dio);

  @override
  Future<_DioImageProvider> obtainKey(ImageConfiguration configuration) {
    return Future.value(this);
  }

  @override
  ImageStreamCompleter loadImage(
    _DioImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
    );
  }

  Future<ui.Codec> _loadAsync(
    _DioImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    final response = await dio.get<List<int>>(
      key.url,
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data!;
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(bytes),
    );
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) {
    if (other is _DioImageProvider) {
      return url == other.url;
    }
    return false;
  }

  @override
  int get hashCode => url.hashCode;
}
