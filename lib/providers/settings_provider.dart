import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class SettingsState {
  final int scrollDuration;
  final bool isAutoScrollEnabled;

  SettingsState({
    required this.scrollDuration,
    required this.isAutoScrollEnabled,
  });

  SettingsState copyWith({int? scrollDuration, bool? isAutoScrollEnabled}) {
    return SettingsState(
      scrollDuration: scrollDuration ?? this.scrollDuration,
      isAutoScrollEnabled: isAutoScrollEnabled ?? this.isAutoScrollEnabled,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    // Note: We'll read prefs from the provider
    final prefs = ref.watch(sharedPreferencesProvider);
    return SettingsState(
      scrollDuration:
          prefs.getInt(AppConstants.keyScrollDuration) ??
          AppConstants.defaultDuration,
      isAutoScrollEnabled:
          prefs.getBool(AppConstants.keyIsAutoScrollEnabled) ?? false,
    );
  }

  void setScrollDuration(int duration) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(AppConstants.keyScrollDuration, duration);
    state = state.copyWith(scrollDuration: duration);
  }

  void setAutoScrollEnabled(bool enabled) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(AppConstants.keyIsAutoScrollEnabled, enabled);
    state = state.copyWith(isAutoScrollEnabled: enabled);
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  () => SettingsNotifier(),
);
