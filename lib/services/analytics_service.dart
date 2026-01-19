import 'package:shared_preferences/shared_preferences.dart';
import '../core/result.dart';

/// Analytics Event Tracker for monitoring user behavior
/// This is production-ready and can be extended to send to Firebase Analytics, Mixpanel, etc.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final List<AnalyticsEvent> _eventLog = [];
  SharedPreferences? _prefs;

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadEventLog();
  }

  /// Log an event
  Future<Result<void>> logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final event = AnalyticsEvent(
        name: eventName,
        timestamp: DateTime.now(),
        parameters: parameters ?? {},
      );

      _eventLog.add(event);

      // Keep only last 100 events in memory
      if (_eventLog.length > 100) {
        _eventLog.removeAt(0);
      }

      await _saveEventLog();

      // In production, send to analytics service here
      // await _sendToAnalyticsService(event);

      return const Success(null);
    } catch (e) {
      return Failure('Failed to log event: $eventName', e as Exception);
    }
  }

  /// Get event history
  List<AnalyticsEvent> getEventHistory({int limit = 50}) {
    return _eventLog.take(limit).toList();
  }

  /// Clear event history
  Future<void> clearHistory() async {
    _eventLog.clear();
    await _prefs?.remove('analytics_event_log');
  }

  Future<void> _saveEventLog() async {
    if (_prefs == null) return;

    final eventStrings = _eventLog.map((e) => e.toJson()).toList();
    await _prefs!.setStringList('analytics_event_log', eventStrings);
  }

  Future<void> _loadEventLog() async {
    if (_prefs == null) return;

    final eventStrings = _prefs!.getStringList('analytics_event_log') ?? [];
    _eventLog.clear();

    for (final eventString in eventStrings) {
      try {
        _eventLog.add(AnalyticsEvent.fromJson(eventString));
      } catch (e) {
        // Skip invalid events
      }
    }
  }
}

class AnalyticsEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;

  AnalyticsEvent({
    required this.name,
    required this.timestamp,
    required this.parameters,
  });

  String toJson() {
    return '$name|${timestamp.toIso8601String()}|${parameters.toString()}';
  }

  factory AnalyticsEvent.fromJson(String json) {
    final parts = json.split('|');
    return AnalyticsEvent(
      name: parts[0],
      timestamp: DateTime.parse(parts[1]),
      parameters: {}, // Simplified for now
    );
  }
}

// Common event names
class AnalyticsEvents {
  static const String appOpened = 'app_opened';
  static const String serviceStarted = 'service_started';
  static const String serviceStopped = 'service_stopped';
  static const String scrollTriggered = 'scroll_triggered';
  static const String settingsChanged = 'settings_changed';
  static const String permissionGranted = 'permission_granted';
  static const String permissionDenied = 'permission_denied';
  static const String overlayShown = 'overlay_shown';
  static const String overlayHidden = 'overlay_hidden';
  static const String sleepTimerActivated = 'sleep_timer_activated';
}
