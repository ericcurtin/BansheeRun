import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsState {
  final bool useMetricUnits;
  final bool audioEnabled;
  final bool keepScreenOn;
  final double defaultPaceSecPerKm;

  const SettingsState({
    this.useMetricUnits = true,
    this.audioEnabled = true,
    this.keepScreenOn = true,
    this.defaultPaceSecPerKm = 360.0, // 6:00/km
  });

  SettingsState copyWith({
    bool? useMetricUnits,
    bool? audioEnabled,
    bool? keepScreenOn,
    double? defaultPaceSecPerKm,
  }) {
    return SettingsState(
      useMetricUnits: useMetricUnits ?? this.useMetricUnits,
      audioEnabled: audioEnabled ?? this.audioEnabled,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      defaultPaceSecPerKm: defaultPaceSecPerKm ?? this.defaultPaceSecPerKm,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier() : super(const SettingsState());

  void setUseMetricUnits(bool value) {
    state = state.copyWith(useMetricUnits: value);
  }

  void setAudioEnabled(bool value) {
    state = state.copyWith(audioEnabled: value);
  }

  void setKeepScreenOn(bool value) {
    state = state.copyWith(keepScreenOn: value);
  }

  void setDefaultPace(double paceSecPerKm) {
    state = state.copyWith(defaultPaceSecPerKm: paceSecPerKm);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    return SettingsNotifier();
  },
);
