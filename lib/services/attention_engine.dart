import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'attention_engine/models.dart';
import 'attention_engine/attention_engine.dart';

export 'attention_engine/models.dart';

class AttentionEngine {
  static final AttentionEngine _instance = AttentionEngine._internal();
  factory AttentionEngine() => _instance;
  AttentionEngine._internal();

  SharedPreferences? _prefs;
  final PureAttentionEngine _engine = PureAttentionEngine();

  // Current Session State
  String _currentPackage = '';

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadLearningData();
  }

  void updateContext({
    required String packageName,
    required bool isAudioActive,
  }) {
    _currentPackage = packageName;
    _engine.setContext(packageName: packageName, isAudioActive: isAudioActive);
  }

  void recordScrollEvent({
    required bool isAutoScroll,
    required bool wasOverridden,
    required Duration timeSinceLastScroll,
  }) {
    if (_currentPackage.isEmpty) return;

    _engine.recordEvent(
      packageName: _currentPackage,
      timeSinceLastScroll: timeSinceLastScroll,
      wasOverridden: wasOverridden,
    );

    _saveLearningData();
  }

  /// Calculates the recommended delay in seconds
  double getRecommendedDelay() {
    final recommendation = _engine.getRecommendation(_currentPackage);
    return recommendation.nextDelay.inMilliseconds / 1000.0;
  }

  double getConfidenceScore() {
    final recommendation = _engine.getRecommendation(_currentPackage);
    return recommendation.confidence;
  }

  List<ScrollRecommendation> getPredictedDelays(int count) {
    return _engine.getMultipleRecommendations(_currentPackage, count);
  }

  Future<void> _loadLearningData() async {
    if (_prefs == null) return;
    final String? jsonStr = _prefs!.getString(AppConstants.keyAttentionData);
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        final data = decoded.map(
          (key, value) => MapEntry(key, AppLearningData.fromJson(value)),
        );
        _engine.updateLearningData(data);
      } catch (e) {
        debugPrint("Error loading attention data: $e");
      }
    }
  }

  Future<void> _saveLearningData() async {
    if (_prefs == null) return;
    final learningData = _engine.learningData;
    final Map<String, dynamic> jsonMap = learningData.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await _prefs!.setString(AppConstants.keyAttentionData, jsonEncode(jsonMap));
  }

  void resetLearning() {
    _engine.updateLearningData({});
    _prefs?.remove(AppConstants.keyAttentionData);
  }
}
