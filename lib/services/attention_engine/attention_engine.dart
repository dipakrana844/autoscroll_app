import 'models.dart';

class PureAttentionEngine {
  // Current Session State
  String _currentPackage = '';
  bool _isAudioActive = false;
  Map<String, AppLearningData> _learningData = {};

  // Constants for Heuristics
  static const double minScrollDelaySeconds = 3.0;
  static const double maxScrollDelaySeconds = 60.0;
  static const double learningRate = 0.1; // Alpha for EMA
  static const double defaultDelaySeconds = 10.0;

  void setContext({required String packageName, required bool isAudioActive}) {
    if (_currentPackage != packageName) {
      _currentPackage = packageName;
      if (!_learningData.containsKey(packageName) && packageName.isNotEmpty) {
        _learningData[packageName] = AppLearningData(
          lastUpdated: DateTime.now(),
        );
      }
    }
    _isAudioActive = isAudioActive;
  }

  void updateLearningData(Map<String, AppLearningData> data) {
    _learningData = Map.from(data);
  }

  Map<String, AppLearningData> get learningData =>
      Map.unmodifiable(_learningData);

  AppLearningData recordEvent({
    required String packageName,
    required Duration timeSinceLastScroll,
    required bool wasOverridden,
  }) {
    final data =
        _learningData[packageName] ??
        AppLearningData(lastUpdated: DateTime.now());

    double currentWatchTime = timeSinceLastScroll.inMilliseconds.toDouble();
    double newAvgWatchTime = data.avgWatchTimeMs;
    int newSampleCount = data.sampleCount;
    int newManualOverrides = data.manualOverrides;
    int newRapidSkips = data.rapidSkips;

    // Filter outlier data (super short or super long)
    if (currentWatchTime > 1000 && currentWatchTime < 300000) {
      newAvgWatchTime =
          (data.avgWatchTimeMs * (1 - learningRate)) +
          (currentWatchTime * learningRate);
      newSampleCount++;
    }

    if (wasOverridden) {
      newManualOverrides++;
    }

    // Check for rapid skips (short watch time)
    if (currentWatchTime < 3000) {
      newRapidSkips++;
    }

    final updatedData = data.copyWith(
      avgWatchTimeMs: newAvgWatchTime,
      sampleCount: newSampleCount,
      manualOverrides: newManualOverrides,
      rapidSkips: newRapidSkips,
      lastUpdated: DateTime.now(),
    );

    _learningData[packageName] = updatedData;
    return updatedData;
  }

  ScrollRecommendation getRecommendation(String packageName) {
    if (packageName.isEmpty) {
      return const ScrollRecommendation(
        nextDelay: Duration(seconds: 10),
        confidence: 0.0,
      );
    }

    final data =
        _learningData[packageName] ??
        AppLearningData(lastUpdated: DateTime.now());
    double baseDelay = data.avgWatchTimeMs / 1000.0;

    // Heuristic 1: Audio Presence
    if (_isAudioActive) {
      baseDelay *= 1.5; // Increase time if listening to audio
    } else {
      baseDelay *= 0.9; // Slightly faster if silent
    }

    // Confidence correction
    double confidence = _calculateConfidence(data);

    // Blend with default based on confidence
    baseDelay =
        (baseDelay * confidence) + (defaultDelaySeconds * (1.0 - confidence));

    // Clamp
    final finalDelay = baseDelay.clamp(
      minScrollDelaySeconds,
      maxScrollDelaySeconds,
    );

    return ScrollRecommendation(
      nextDelay: Duration(milliseconds: (finalDelay * 1000).round()),
      confidence: confidence,
    );
  }

  double _calculateConfidence(AppLearningData data) {
    if (data.sampleCount < 5) return 0.1;
    // Simple confidence based on sample size
    return (data.sampleCount / 50.0).clamp(0.0, 1.0);
  }

  List<ScrollRecommendation> getMultipleRecommendations(
    String packageName,
    int count,
  ) {
    final recommendation = getRecommendation(packageName);
    final List<ScrollRecommendation> list = [];

    for (int i = 0; i < count; i++) {
      // For preview, we might want to add some simulated variance if needed,
      // but for now, just return the same predicted delay for simplicity
      // as the engine is deterministic without new events.
      list.add(recommendation);
    }
    return list;
  }
}
