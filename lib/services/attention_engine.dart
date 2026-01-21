import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';

class AppLearningData {
  double avgWatchTimeMs;
  int sampleCount;
  int manualOverrides;
  int rapidSkips;
  DateTime lastUpdated;

  AppLearningData({
    this.avgWatchTimeMs = 10000.0, // Default 10s
    this.sampleCount = 0,
    this.manualOverrides = 0,
    this.rapidSkips = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'avgWatchTimeMs': avgWatchTimeMs,
    'sampleCount': sampleCount,
    'manualOverrides': manualOverrides,
    'rapidSkips': rapidSkips,
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory AppLearningData.fromJson(Map<String, dynamic> json) {
    return AppLearningData(
      avgWatchTimeMs: json['avgWatchTimeMs']?.toDouble() ?? 10000.0,
      sampleCount: json['sampleCount'] ?? 0,
      manualOverrides: json['manualOverrides'] ?? 0,
      rapidSkips: json['rapidSkips'] ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'])
          : null,
    );
  }
}

class AttentionEngine {
  static final AttentionEngine _instance = AttentionEngine._internal();
  factory AttentionEngine() => _instance;
  AttentionEngine._internal();

  SharedPreferences? _prefs;
  Map<String, AppLearningData> _learningData = {};

  // Current Session State
  String _currentPackage = '';
  bool _isAudioActive = false;

  // Constants for Heuristics
  static const double _minScrollDelay = 3.0; // Seconds
  static const double _maxScrollDelay = 60.0;
  static const double _learningRate = 0.1; // Alpha for EMA

  Future<void> initialize(SharedPreferences prefs) async {
    _prefs = prefs;
    await _loadLearningData();
  }

  void updateContext({
    required String packageName,
    required bool isAudioActive,
  }) {
    if (_currentPackage != packageName) {
      _currentPackage = packageName;
      // Initialize if new
      if (!_learningData.containsKey(packageName) && packageName.isNotEmpty) {
        _learningData[packageName] = AppLearningData();
      }
    }
    _isAudioActive = isAudioActive;
  }

  void recordScrollEvent({
    required bool isAutoScroll,
    required bool wasOverridden, // User manually scrolled back/cancelled
    required Duration timeSinceLastScroll,
  }) {
    if (_currentPackage.isEmpty) return;

    final data = _learningData[_currentPackage] ?? AppLearningData();

    // Update Watch Time Learning (EMA)
    double currentWatchTime = timeSinceLastScroll.inMilliseconds.toDouble();

    // Filter outlier data (super short or super long)
    if (currentWatchTime > 1000 && currentWatchTime < 300000) {
      data.avgWatchTimeMs =
          (data.avgWatchTimeMs * (1 - _learningRate)) +
          (currentWatchTime * _learningRate);
      data.sampleCount++;
    }

    if (wasOverridden) {
      data.manualOverrides++;
    }

    // Check for rapid skips (short watch time)
    if (currentWatchTime < 3000) {
      // Less than 3 seconds
      data.rapidSkips++;
    }

    data.lastUpdated = DateTime.now();
    _learningData[_currentPackage] = data;

    _saveLearningData();
  }

  /// Calculates the recommended delay in seconds
  double getRecommendedDelay() {
    print(
      "AttentionEngine: Calculating delay for $_currentPackage, Audio: $_isAudioActive",
    );
    if (_currentPackage.isEmpty) return 10.0; // Default

    final data = _learningData[_currentPackage] ?? AppLearningData();

    double baseDelay = data.avgWatchTimeMs / 1000.0;

    // Heuristic 1: Audio Presence
    if (_isAudioActive) {
      baseDelay *= 1.5; // Increase time if listening to audio
    } else {
      baseDelay *= 0.9; // Slightly faster if silent
    }

    // Heuristic 2: User Overrides (User scrolls back implies we were too fast)
    // Heuristic 3: Rapid Skips (User scrolls fast implies boring content, but we want to know desired speed)
    // If user skips fast, our avgWatchTime drops, so baseDelay drops naturally.

    // Confidence correction
    double confidence = getConfidenceScore();

    // Blend with default based on confidence
    baseDelay = (baseDelay * confidence) + (10.0 * (1.0 - confidence));

    // Clamp
    return baseDelay.clamp(_minScrollDelay, _maxScrollDelay);
  }

  double getConfidenceScore() {
    if (_currentPackage.isEmpty) return 0.0;
    final data = _learningData[_currentPackage];
    if (data == null || data.sampleCount < 5) return 0.1; // Low confidence

    // Simple confidence based on sample size
    return (data.sampleCount / 50.0).clamp(0.0, 1.0);
  }

  Future<void> _loadLearningData() async {
    if (_prefs == null) return;
    final String? jsonStr = _prefs!.getString(AppConstants.keyAttentionData);
    if (jsonStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(jsonStr);
        _learningData = decoded.map(
          (key, value) => MapEntry(key, AppLearningData.fromJson(value)),
        );
      } catch (e) {
        debugPrint("Error loading attention data: $e");
      }
    }
  }

  Future<void> _saveLearningData() async {
    if (_prefs == null) return;
    final Map<String, dynamic> jsonMap = _learningData.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await _prefs!.setString(AppConstants.keyAttentionData, jsonEncode(jsonMap));
  }

  void resetLearning() {
    _learningData.clear();
    _prefs?.remove(AppConstants.keyAttentionData);
  }
}
