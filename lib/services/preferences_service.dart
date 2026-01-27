import 'package:shared_preferences/shared_preferences.dart';

/// User Preferences Service
/// Manages all user settings and preferences in a centralized way
class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  SharedPreferences? _prefs;

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  // App Settings
  Future<void> setScrollDuration(int seconds) async {
    await _prefs?.setInt('scroll_duration', seconds);
  }

  int getScrollDuration() {
    return _prefs?.getInt('scroll_duration') ?? 10;
  }

  Future<void> setRandomVariance(int seconds) async {
    await _prefs?.setInt('random_variance', seconds);
  }

  int getRandomVariance() {
    return _prefs?.getInt('random_variance') ?? 0;
  }

  Future<void> setSleepTimer(int minutes) async {
    await _prefs?.setInt('sleep_timer_minutes', minutes);
  }

  int getSleepTimer() {
    return _prefs?.getInt('sleep_timer_minutes') ?? 0;
  }

  Future<void> setAutoScrollEnabled(bool enabled) async {
    await _prefs?.setBool('is_auto_scroll_enabled', enabled);
  }

  bool getAutoScrollEnabled() {
    return _prefs?.getBool('is_auto_scroll_enabled') ?? false;
  }

  // Usage Statistics
  Future<void> incrementScrollCount() async {
    final current = getScrollCount();
    await _prefs?.setInt('total_scroll_count', current + 1);
  }

  int getScrollCount() {
    return _prefs?.getInt('total_scroll_count') ?? 0;
  }

  Future<void> updateTotalUsageTime(int seconds) async {
    final current = getTotalUsageTime();
    await _prefs?.setInt('total_usage_time_seconds', current + seconds);
  }

  int getTotalUsageTime() {
    return _prefs?.getInt('total_usage_time_seconds') ?? 0;
  }

  Future<void> setSessionStart(DateTime time) async {
    await _prefs?.setString('last_session_start', time.toIso8601String());
  }

  DateTime? getSessionStart() {
    final start = _prefs?.getString('last_session_start');
    return start != null ? DateTime.tryParse(start) : null;
  }

  Future<void> clearSessionStart() async {
    await _prefs?.remove('last_session_start');
  }

  // First Launch
  Future<void> setFirstLaunchComplete() async {
    await _prefs?.setBool('first_launch_complete', true);
  }

  bool isFirstLaunch() {
    return !(_prefs?.getBool('first_launch_complete') ?? false);
  }

  // App Version (for migration purposes)
  Future<void> setAppVersion(String version) async {
    await _prefs?.setString('app_version', version);
  }

  String? getAppVersion() {
    return _prefs?.getString('app_version');
  }

  // Last Active Date
  Future<void> updateLastActiveDate() async {
    await _prefs?.setString(
      'last_active_date',
      DateTime.now().toIso8601String(),
    );
  }

  DateTime? getLastActiveDate() {
    final dateString = _prefs?.getString('last_active_date');
    return dateString != null ? DateTime.tryParse(dateString) : null;
  }

  // Clear all preferences
  Future<void> clearAll() async {
    await _prefs?.clear();
  }
}
