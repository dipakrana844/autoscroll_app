import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
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

  void updateScrollDuration(int duration) {
    state = state.copyWith(scrollDuration: duration);
  }

  void saveScrollDuration(int duration) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(AppConstants.keyScrollDuration, duration);
    // Ensure state is updated (if not already)
    if (state.scrollDuration != duration) {
      state = state.copyWith(scrollDuration: duration);
    }

    // Sync with overlay
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({'scrollDuration': duration});
      }
    } catch (e) {
      // Ignore errors if overlay is not available
    }
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
