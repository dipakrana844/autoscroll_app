import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../core/constants.dart';
import '../services/analytics_service.dart';

class SettingsState {
  final int scrollDuration;
  final bool isAutoScrollEnabled;
  final int randomVariance;
  final int sleepTimerMinutes;

  SettingsState({
    required this.scrollDuration,
    required this.isAutoScrollEnabled,
    required this.randomVariance,
    required this.sleepTimerMinutes,
  });

  SettingsState copyWith({
    int? scrollDuration,
    bool? isAutoScrollEnabled,
    int? randomVariance,
    int? sleepTimerMinutes,
  }) {
    return SettingsState(
      scrollDuration: scrollDuration ?? this.scrollDuration,
      isAutoScrollEnabled: isAutoScrollEnabled ?? this.isAutoScrollEnabled,
      randomVariance: randomVariance ?? this.randomVariance,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  final _analytics = AnalyticsService();

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
      randomVariance:
          prefs.getInt(AppConstants.keyRandomVariance) ??
          AppConstants.defaultVariance,
      sleepTimerMinutes:
          prefs.getInt(AppConstants.keySleepTimerMinutes) ??
          AppConstants.defaultSleepTimer,
    );
  }

  void updateScrollDuration(int duration) {
    state = state.copyWith(scrollDuration: duration);
  }

  void saveScrollDuration(int duration) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(AppConstants.keyScrollDuration, duration);
    if (state.scrollDuration != duration) {
      state = state.copyWith(scrollDuration: duration);
    }
    _syncToOverlay();

    // Track analytics
    _analytics.logEvent(
      AnalyticsEvents.settingsChanged,
      parameters: {'setting': 'scroll_duration', 'value': duration},
    );
  }

  void updateRandomVariance(int variance) {
    state = state.copyWith(randomVariance: variance);
  }

  void saveRandomVariance(int variance) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(AppConstants.keyRandomVariance, variance);
    if (state.randomVariance != variance) {
      state = state.copyWith(randomVariance: variance);
    }
    _syncToOverlay();

    // Track analytics
    _analytics.logEvent(
      AnalyticsEvents.settingsChanged,
      parameters: {'setting': 'random_variance', 'value': variance},
    );
  }

  void updateSleepTimer(int minutes) {
    state = state.copyWith(sleepTimerMinutes: minutes);
  }

  void saveSleepTimer(int minutes) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(AppConstants.keySleepTimerMinutes, minutes);
    if (state.sleepTimerMinutes != minutes) {
      state = state.copyWith(sleepTimerMinutes: minutes);
    }
    _syncToOverlay();

    // Track analytics
    _analytics.logEvent(
      AnalyticsEvents.settingsChanged,
      parameters: {'setting': 'sleep_timer', 'value': minutes},
    );

    if (minutes > 0) {
      _analytics.logEvent(AnalyticsEvents.sleepTimerActivated);
    }
  }

  void setAutoScrollEnabled(bool enabled) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(AppConstants.keyIsAutoScrollEnabled, enabled);
    state = state.copyWith(isAutoScrollEnabled: enabled);

    // Track analytics
    _analytics.logEvent(
      enabled ? AnalyticsEvents.serviceStarted : AnalyticsEvents.serviceStopped,
    );
  }

  Future<void> _syncToOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'scrollDuration': state.scrollDuration,
          'randomVariance': state.randomVariance,
          'sleepTimerMinutes': state.sleepTimerMinutes,
        });
      }
    } catch (e) {
      // Ignore errors if overlay is not available
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(
  () => SettingsNotifier(),
);
