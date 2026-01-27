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
  final bool isAIAttentionModeEnabled;
  final bool showScrollPreview;

  SettingsState({
    required this.scrollDuration,
    required this.isAutoScrollEnabled,
    required this.randomVariance,
    required this.sleepTimerMinutes,
    required this.isAIAttentionModeEnabled,
    required this.showScrollPreview,
  });

  SettingsState copyWith({
    int? scrollDuration,
    bool? isAutoScrollEnabled,
    int? randomVariance,
    int? sleepTimerMinutes,
    bool? isAIAttentionModeEnabled,
    bool? showScrollPreview,
  }) {
    return SettingsState(
      scrollDuration: scrollDuration ?? this.scrollDuration,
      isAutoScrollEnabled: isAutoScrollEnabled ?? this.isAutoScrollEnabled,
      randomVariance: randomVariance ?? this.randomVariance,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
      isAIAttentionModeEnabled:
          isAIAttentionModeEnabled ?? this.isAIAttentionModeEnabled,
      showScrollPreview: showScrollPreview ?? this.showScrollPreview,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  final _analytics = AnalyticsService();

  @override
  SettingsState build() {
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
      isAIAttentionModeEnabled:
          prefs.getBool(AppConstants.keyEnableAIAttentionMode) ?? false,
      showScrollPreview:
          prefs.getBool(AppConstants.keyShowScrollPreview) ??
          AppConstants.defaultShowScrollPreview,
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

    _analytics.logEvent(
      enabled ? AnalyticsEvents.serviceStarted : AnalyticsEvents.serviceStopped,
    );
  }

  void setAIAttentionModeEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyEnableAIAttentionMode, enabled);
    state = state.copyWith(isAIAttentionModeEnabled: enabled);
    _syncToOverlay();

    _analytics.logEvent(
      AnalyticsEvents.settingsChanged,
      parameters: {'setting': 'ai_attention_mode', 'value': enabled},
    );
    if (enabled) {
      _analytics.logEvent(AnalyticsEvents.attentionModeEnabled);
    }
  }

  void setShowScrollPreview(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(AppConstants.keyShowScrollPreview, enabled);
    state = state.copyWith(showScrollPreview: enabled);
    _syncToOverlay();

    _analytics.logEvent(
      AnalyticsEvents.settingsChanged,
      parameters: {'setting': 'show_scroll_preview', 'value': enabled},
    );
  }

  Future<void> _syncToOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'scrollDuration': state.scrollDuration,
          'randomVariance': state.randomVariance,
          'sleepTimerMinutes': state.sleepTimerMinutes,
          'isAIAttentionModeEnabled': state.isAIAttentionModeEnabled,
          'showScrollPreview': state.showScrollPreview,
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
