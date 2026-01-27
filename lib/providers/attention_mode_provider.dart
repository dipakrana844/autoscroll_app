import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/attention_engine.dart';
import '../services/analytics_service.dart';
import 'settings_provider.dart';

class AttentionModeState {
  final bool isEnabled;
  final double currentSuggestedDelay;
  final double confidenceScore;
  final String currentPackage;
  final bool isAudioActive;
  final List<double> predictedDelays;

  AttentionModeState({
    required this.isEnabled,
    required this.currentSuggestedDelay,
    required this.confidenceScore,
    required this.currentPackage,
    required this.isAudioActive,
    required this.predictedDelays,
  });

  AttentionModeState copyWith({
    bool? isEnabled,
    double? currentSuggestedDelay,
    double? confidenceScore,
    String? currentPackage,
    bool? isAudioActive,
    List<double>? predictedDelays,
  }) {
    return AttentionModeState(
      isEnabled: isEnabled ?? this.isEnabled,
      currentSuggestedDelay:
          currentSuggestedDelay ?? this.currentSuggestedDelay,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      currentPackage: currentPackage ?? this.currentPackage,
      isAudioActive: isAudioActive ?? this.isAudioActive,
      predictedDelays: predictedDelays ?? this.predictedDelays,
    );
  }
}

class AttentionModeNotifier extends Notifier<AttentionModeState> {
  final _engine = AttentionEngine();
  final _analytics = AnalyticsService();

  @override
  AttentionModeState build() {
    final settings = ref.watch(settingsProvider);
    return AttentionModeState(
      isEnabled: settings.isAIAttentionModeEnabled,
      currentSuggestedDelay: 10.0,
      confidenceScore: 0.0,
      currentPackage: '',
      isAudioActive: false,
      predictedDelays: const [],
    );
  }

  void updateContext({
    required String packageName,
    required bool isAudioActive,
  }) {
    // Only update if changed to avoid rebuilds
    if (state.currentPackage == packageName &&
        state.isAudioActive == isAudioActive) {
      return;
    }

    _engine.updateContext(
      packageName: packageName,
      isAudioActive: isAudioActive,
    );

    // Recalculate immediately when context changes
    final newDelay = _engine.getRecommendedDelay();
    final confidence = _engine.getConfidenceScore();
    final predictions = _engine
        .getPredictedDelays(5)
        .map((r) => r.nextDelay.inMilliseconds / 1000.0)
        .toList();

    state = state.copyWith(
      currentPackage: packageName,
      isAudioActive: isAudioActive,
      currentSuggestedDelay: newDelay,
      confidenceScore: confidence,
      predictedDelays: predictions,
    );

    _syncToOverlay();

    // Log if significant change
    if (state.isEnabled) {
      _analytics.logEvent(
        AnalyticsEvents.aiScrollDecision,
        parameters: {
          'delay': newDelay,
          'confidence': confidence,
          'package': packageName,
          'audio': isAudioActive,
        },
      );
    }
  }

  void recordScroll({required bool success, required Duration duration}) {
    if (!state.isEnabled) return;

    // We assume successful auto-scroll.
    // "wasOverridden" should be detected if the user taps/scrolls manually soon after.
    // For now, we'll treat every "trigger" as a sample point unless we have a way to detect override.
    // The user requirement says "User manual scroll overrides".
    // Implementation: If we trigger a scroll, and then receive a manual scroll event within X seconds?
    // Native accessibility service sends "Scroll" commands, but does it send "User Scrolled"?
    // The current native service sends 'onAppChanged'. It doesn't seem to send 'onUserInteraction'.
    // We will assume 'duration' passed here is the 'time since last scroll' which effectively is the watch time.

    _engine.recordScrollEvent(
      isAutoScroll: true,
      wasOverridden: false, // Initial assumption
      timeSinceLastScroll: duration,
    );

    // Recalculate for next time
    final newDelay = _engine.getRecommendedDelay();
    final confidence = _engine.getConfidenceScore();
    final predictions = _engine
        .getPredictedDelays(5)
        .map((r) => r.nextDelay.inMilliseconds / 1000.0)
        .toList();

    state = state.copyWith(
      currentSuggestedDelay: newDelay,
      confidenceScore: confidence,
      predictedDelays: predictions,
    );

    _syncToOverlay();

    _analytics.logEvent(
      AnalyticsEvents.learningUpdated,
      parameters: {'new_delay': newDelay},
    );
  }

  void resetLearning() {
    _engine.resetLearning();
    state = state.copyWith(currentSuggestedDelay: 10.0, confidenceScore: 0.0);
    _syncToOverlay();
  }

  Future<void> _syncToOverlay() async {
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData({
          'aiSuggestedDelay': state.currentSuggestedDelay,
          'aiConfidence': state.confidenceScore,
          'predictedDelays': state.predictedDelays,
          // We don't send isEnabled because settings provider sends it.
          // But main sync might be slower, so we can send here too if needed.
        });
      }
    } catch (e) {
      // Ignore
    }
  }
}

final attentionModeProvider =
    NotifierProvider<AttentionModeNotifier, AttentionModeState>(
      () => AttentionModeNotifier(),
    );
