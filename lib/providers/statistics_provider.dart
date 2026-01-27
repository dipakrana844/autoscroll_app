import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/preferences_service.dart';
import '../services/analytics_service.dart';

class StatisticsState {
  final int totalUsageSeconds;
  final int totalScrollCount;
  final List<AnalyticsEvent> events;
  final DateTime? lastActive;

  StatisticsState({
    required this.totalUsageSeconds,
    required this.totalScrollCount,
    required this.events,
    this.lastActive,
  });

  String get formattedUsageTime {
    final duration = Duration(seconds: totalUsageSeconds);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class StatisticsNotifier extends StateNotifier<StatisticsState> {
  Timer? _refreshTimer;

  StatisticsNotifier() : super(_loadInitial()) {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      refresh();
    });
  }

  static StatisticsState _loadInitial() {
    final prefs = PreferencesService();
    final analytics = AnalyticsService();

    return StatisticsState(
      totalUsageSeconds: prefs.getTotalUsageTime(),
      totalScrollCount: prefs.getScrollCount(),
      events: analytics.getEventHistory(limit: 20),
      lastActive: prefs.getLastActiveDate(),
    );
  }

  void refresh() {
    final prefs = PreferencesService();
    final analytics = AnalyticsService();

    state = StatisticsState(
      totalUsageSeconds: prefs.getTotalUsageTime(),
      totalScrollCount: prefs.getScrollCount(),
      events: analytics.getEventHistory(limit: 20),
      lastActive: prefs.getLastActiveDate(),
    );
  }

  Future<void> clearHistory() async {
    final analytics = AnalyticsService();
    await analytics.clearHistory();
    refresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

final statisticsProvider =
    StateNotifierProvider.autoDispose<StatisticsNotifier, StatisticsState>((
      ref,
    ) {
      return StatisticsNotifier();
    });
