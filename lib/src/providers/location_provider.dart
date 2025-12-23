import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:banshee_run_app/src/services/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final currentPositionProvider = StreamProvider<Position?>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return locationService.positionStream.map((pos) => pos);
});

final locationPermissionProvider = FutureProvider<bool>((ref) async {
  final locationService = ref.watch(locationServiceProvider);
  return await locationService.checkPermission();
});

class LocationState {
  final Position? currentPosition;
  final bool isTracking;
  final bool hasPermission;
  final String? error;

  const LocationState({
    this.currentPosition,
    this.isTracking = false,
    this.hasPermission = false,
    this.error,
  });

  LocationState copyWith({
    Position? currentPosition,
    bool? isTracking,
    bool? hasPermission,
    String? error,
  }) {
    return LocationState(
      currentPosition: currentPosition ?? this.currentPosition,
      isTracking: isTracking ?? this.isTracking,
      hasPermission: hasPermission ?? this.hasPermission,
      error: error,
    );
  }
}

class LocationNotifier extends StateNotifier<LocationState> {
  final LocationService _locationService;
  StreamSubscription<Position>? _subscription;

  LocationNotifier(this._locationService) : super(const LocationState());

  Future<void> init() async {
    final hasPermission = await _locationService.checkPermission();
    state = state.copyWith(hasPermission: hasPermission);

    if (hasPermission) {
      final position = await _locationService.getCurrentPosition();
      state = state.copyWith(currentPosition: position);
    }
  }

  Future<bool> requestPermission() async {
    final hasPermission = await _locationService.checkPermission();
    state = state.copyWith(hasPermission: hasPermission);
    return hasPermission;
  }

  Future<void> startTracking() async {
    if (!state.hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        state = state.copyWith(error: 'Location permission denied');
        return;
      }
    }

    final success = await _locationService.startTracking();
    if (success) {
      _subscription = _locationService.positionStream.listen((position) {
        state = state.copyWith(currentPosition: position);
      });
      state = state.copyWith(isTracking: true, error: null);
    } else {
      state = state.copyWith(error: 'Failed to start location tracking');
    }
  }

  Future<void> stopTracking() async {
    await _subscription?.cancel();
    _subscription = null;
    await _locationService.stopTracking();
    state = state.copyWith(isTracking: false);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final locationNotifierProvider =
    StateNotifierProvider<LocationNotifier, LocationState>((ref) {
      final locationService = ref.watch(locationServiceProvider);
      return LocationNotifier(locationService);
    });
