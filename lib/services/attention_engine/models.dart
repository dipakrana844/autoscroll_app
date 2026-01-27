class AppLearningData {
  final double avgWatchTimeMs;
  final int sampleCount;
  final int manualOverrides;
  final int rapidSkips;
  final DateTime lastUpdated;

  const AppLearningData({
    this.avgWatchTimeMs = 10000.0, // Default 10s
    this.sampleCount = 0,
    this.manualOverrides = 0,
    this.rapidSkips = 0,
    required this.lastUpdated,
  });

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
          : DateTime.now(),
    );
  }

  AppLearningData copyWith({
    double? avgWatchTimeMs,
    int? sampleCount,
    int? manualOverrides,
    int? rapidSkips,
    DateTime? lastUpdated,
  }) {
    return AppLearningData(
      avgWatchTimeMs: avgWatchTimeMs ?? this.avgWatchTimeMs,
      sampleCount: sampleCount ?? this.sampleCount,
      manualOverrides: manualOverrides ?? this.manualOverrides,
      rapidSkips: rapidSkips ?? this.rapidSkips,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class ScrollRecommendation {
  final Duration nextDelay;
  final double confidence;

  const ScrollRecommendation({
    required this.nextDelay,
    required this.confidence,
  });
}
