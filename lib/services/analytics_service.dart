import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/result.dart';

/// Analytics Event Tracker for monitoring user behavior
/// Optimized with batched SharedPreferences writes.
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  final List<AnalyticsEvent> _eventLog = [];
  SharedPreferences? _prefs;
  Timer? _batchTimer;
  bool _needsPersist = false;

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadEventLog();

    // Setup periodic batch write every 10 seconds if needed
    _batchTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_needsPersist) {
        _saveEventLog();
      }
    });
  }

  /// Log an event
  Future<Result<void>> logEvent(
    String eventName, {
    Map<String, dynamic>? parameters,
  }) async {
    try {
      final now = DateTime.now();

      // Debounce logic: Prevent duplicate events within 500ms
      if (_shouldThrottle(eventName, now)) {
        return const Success(null);
      }
      _lastLogged[eventName] = now;

      final event = AnalyticsEvent(
        name: eventName,
        timestamp: now,
        parameters: parameters ?? {},
      );

      _eventLog.add(event);

      // Keep only last 100 events in memory
      if (_eventLog.length > 100) {
        _eventLog.removeAt(0);
      }

      _needsPersist = true;

      // If we have many events, force a write
      if (_eventLog.length % 10 == 0) {
        await _saveEventLog();
      }

      return const Success(null);
    } catch (e) {
      return Failure('Failed to log event: $eventName', e as Exception);
    }
  }

  final Map<String, DateTime> _lastLogged = {};

  bool _shouldThrottle(String eventName, DateTime now) {
    if (!_lastLogged.containsKey(eventName)) return false;
    final lastTime = _lastLogged[eventName]!;
    return now.difference(lastTime).inMilliseconds < 500;
  }

  /// Get event history
  List<AnalyticsEvent> getEventHistory({int limit = 50}) {
    return _eventLog.reversed.take(limit).toList();
  }

  /// Clear event history
  Future<void> clearHistory() async {
    _eventLog.clear();
    _needsPersist = false;
    await _prefs?.remove('analytics_event_log');
  }

  Future<void> _saveEventLog() async {
    if (_prefs == null || !_needsPersist) return;

    try {
      final eventStrings = _eventLog.map((e) => e.toJson()).toList();
      await _prefs!.setStringList('analytics_event_log', eventStrings);
      _needsPersist = false;
    } catch (e) {
      // Failed to save, will try again next batch
    }
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

  void dispose() {
    _batchTimer?.cancel();
    if (_needsPersist) {
      _saveEventLog();
    }
  }
}

class AnalyticsEvent {
  final String name;
  final DateTime timestamp;
  final Map<String, dynamic> parameters;

  const AnalyticsEvent({
    required this.name,
    required this.timestamp,
    required this.parameters,
  });

  String toJson() {
    return '$name|${timestamp.toIso8601String()}|${parameters.toString()}';
  }

  factory AnalyticsEvent.fromJson(String json) {
    final parts = json.split('|');
    Map<String, dynamic> params = {};
    if (parts.length > 2) {
      try {
        final paramString = parts.sublist(2).join('|');
        String cleanParams = paramString.trim();
        if (cleanParams.startsWith('{') && cleanParams.endsWith('}')) {
          cleanParams = cleanParams.substring(1, cleanParams.length - 1);
        }
        if (cleanParams.isNotEmpty) {
          final entries = cleanParams.split(',');
          for (var entry in entries) {
            final kv = entry.split(':');
            if (kv.length == 2) {
              params[kv[0].trim()] = kv[1].trim();
            }
          }
        }
      } catch (e) {
        // Parsing failed, ignore params
      }
    }

    return AnalyticsEvent(
      name: parts[0],
      timestamp: DateTime.parse(parts[1]),
      parameters: params,
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
  static const String attentionModeEnabled = 'attention_mode_enabled';
  static const String aiScrollDecision = 'ai_scroll_decision';
  static const String userOverrideDetected = 'user_override_detected';
  static const String learningUpdated = 'learning_updated';
}
