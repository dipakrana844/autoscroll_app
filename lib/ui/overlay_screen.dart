import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/analytics_service.dart';

class OverlayData {
  final int countdown;
  final bool isPlaying;
  final bool isScrolling;
  final double aiDelay;
  final double aiConfidence;
  final List<double> predictedDelays;
  final bool isAIEnabled;
  final bool showPreview;
  final int baseDuration;
  final int randomVariance;
  final int sleepTimerMinutes;

  const OverlayData({
    this.countdown = 10,
    this.isPlaying = false,
    this.isScrolling = false,
    this.aiDelay = 10.0,
    this.aiConfidence = 0.0,
    this.predictedDelays = const [],
    this.isAIEnabled = false,
    this.showPreview = false,
    this.baseDuration = 10,
    this.randomVariance = 0,
    this.sleepTimerMinutes = 0,
  });

  OverlayData copyWith({
    int? countdown,
    bool? isPlaying,
    bool? isScrolling,
    double? aiDelay,
    double? aiConfidence,
    List<double>? predictedDelays,
    bool? isAIEnabled,
    bool? showPreview,
    int? baseDuration,
    int? randomVariance,
    int? sleepTimerMinutes,
  }) {
    return OverlayData(
      countdown: countdown ?? this.countdown,
      isPlaying: isPlaying ?? this.isPlaying,
      isScrolling: isScrolling ?? this.isScrolling,
      aiDelay: aiDelay ?? this.aiDelay,
      aiConfidence: aiConfidence ?? this.aiConfidence,
      predictedDelays: predictedDelays ?? this.predictedDelays,
      isAIEnabled: isAIEnabled ?? this.isAIEnabled,
      showPreview: showPreview ?? this.showPreview,
      baseDuration: baseDuration ?? this.baseDuration,
      randomVariance: randomVariance ?? this.randomVariance,
      sleepTimerMinutes: sleepTimerMinutes ?? this.sleepTimerMinutes,
    );
  }
}

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  late final ValueNotifier<OverlayData> _stateNotifier;
  DateTime? _startTime;
  Timer? _timer;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _stateNotifier = ValueNotifier(const OverlayData());
    _loadSettings();
    _setupOverlayListener();
  }

  void _setupOverlayListener() {
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        final current = _stateNotifier.value;
        var next = current;

        if (event.containsKey('scrollDuration')) {
          next = next.copyWith(baseDuration: event['scrollDuration'] as int);
        }
        if (event.containsKey('randomVariance')) {
          next = next.copyWith(randomVariance: event['randomVariance'] as int);
        }
        if (event.containsKey('sleepTimerMinutes')) {
          next = next.copyWith(
            sleepTimerMinutes: event['sleepTimerMinutes'] as int,
          );
        }
        if (event.containsKey('isAIAttentionModeEnabled')) {
          next = next.copyWith(
            isAIEnabled: event['isAIAttentionModeEnabled'] as bool,
          );
        }
        if (event.containsKey('showScrollPreview')) {
          next = next.copyWith(showPreview: event['showScrollPreview'] as bool);
        }
        if (event.containsKey('aiSuggestedDelay')) {
          next = next.copyWith(
            aiDelay: (event['aiSuggestedDelay'] as num).toDouble(),
          );
        }
        if (event.containsKey('aiConfidence')) {
          next = next.copyWith(
            aiConfidence: (event['aiConfidence'] as num).toDouble(),
          );
        }
        if (event.containsKey('predictedDelays')) {
          next = next.copyWith(
            predictedDelays: (event['predictedDelays'] as List)
                .map((e) => (e as num).toDouble())
                .toList(),
          );
        }

        if (next != current) {
          if (!current.isPlaying && !current.isScrolling) {
            next = next.copyWith(countdown: _calculateNextCountdown(next));
          }
          _stateNotifier.value = next;
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs != null) {
      final baseDuration =
          _prefs!.getInt(AppConstants.keyScrollDuration) ??
          AppConstants.defaultDuration;
      final randomVariance =
          _prefs!.getInt(AppConstants.keyRandomVariance) ??
          AppConstants.defaultVariance;
      final sleepTimerMinutes =
          _prefs!.getInt(AppConstants.keySleepTimerMinutes) ??
          AppConstants.defaultSleepTimer;
      final isAIEnabled =
          _prefs!.getBool(AppConstants.keyEnableAIAttentionMode) ?? false;
      final showPreview =
          _prefs!.getBool(AppConstants.keyShowScrollPreview) ??
          AppConstants.defaultShowScrollPreview;

      final next = _stateNotifier.value.copyWith(
        baseDuration: baseDuration,
        randomVariance: randomVariance,
        sleepTimerMinutes: sleepTimerMinutes,
        isAIEnabled: isAIEnabled,
        showPreview: showPreview,
      );

      _stateNotifier.value = next.copyWith(
        countdown: _calculateNextCountdown(next),
      );
    }
  }

  int _calculateNextCountdown(OverlayData data) {
    int targetDuration = data.isAIEnabled
        ? data.aiDelay.round()
        : data.baseDuration;

    if (data.randomVariance > 0) {
      final random = Random();
      final variance =
          random.nextInt(data.randomVariance * 2 + 1) - data.randomVariance;
      return max(3, targetDuration + variance);
    }
    return targetDuration;
  }

  void _startTimer() {
    _startTime = DateTime.now();
    _stateNotifier.value = _stateNotifier.value.copyWith(
      isPlaying: true,
      countdown: _calculateNextCountdown(_stateNotifier.value),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final current = _stateNotifier.value;

      // Check Sleep Timer
      if (current.sleepTimerMinutes > 0 && _startTime != null) {
        final elapsed = DateTime.now().difference(_startTime!);
        if (elapsed.inMinutes >= current.sleepTimerMinutes) {
          _stopTimer();
          return;
        }
      }

      if (current.countdown > 1) {
        _stateNotifier.value = current.copyWith(
          countdown: current.countdown - 1,
        );
      } else {
        _triggerScroll();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _startTime = null;
    final next = _stateNotifier.value.copyWith(isPlaying: false);
    _stateNotifier.value = next.copyWith(
      countdown: _calculateNextCountdown(next),
    );
  }

  Future<void> _triggerScroll() async {
    if (_stateNotifier.value.isScrolling) return;

    _stateNotifier.value = _stateNotifier.value.copyWith(isScrolling: true);

    try {
      final service = FlutterBackgroundService();
      service.invoke('trigger_scroll');
      service.invoke('log_event', {'name': AnalyticsEvents.scrollTriggered});
    } catch (e) {
      debugPrint("Overlay Scroll Error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      final current = _stateNotifier.value;
      final next = current.copyWith(
        isScrolling: false,
        countdown: current.isPlaying
            ? _calculateNextCountdown(current)
            : (current.isAIEnabled
                  ? current.aiDelay.round()
                  : current.baseDuration),
      );
      _stateNotifier.value = next;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ValueListenableBuilder<OverlayData>(
        valueListenable: _stateNotifier,
        builder: (context, data, _) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.drag_handle,
                      color: Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    if (data.isAIEnabled) _buildAIBadge(data.aiConfidence),
                    const SizedBox(height: 4),
                    _buildCountdownIndicator(data),
                    if (data.showPreview && data.predictedDelays.isNotEmpty)
                      _buildScrollPreview(data.predictedDelays),
                    const SizedBox(height: 10),
                    _buildControlButtons(data),
                    // const SizedBox(height: 8),
                    // Text(
                    //   data.isScrolling ? "SCROLLING..." : "NEXT",
                    //   style: TextStyle(
                    //     color: data.isScrolling ? Colors.blue : Colors.white30,
                    //     fontSize: 10,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAIBadge(double confidence) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x33448AFF), // 0.2 Alpha, blueAccent R68 G138 B255
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF448AFF), // Full Alpha blueAccent
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF448AFF), size: 10),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              "${(confidence * 100).toInt()}% Confidence",
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownIndicator(OverlayData data) {
    return Container(
      width: 55,
      height: 55,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: data.isScrolling
              ? Colors.blue
              : (data.isAIEnabled
                    ? Colors.blueAccent
                    : (data.isPlaying ? Colors.orange : Colors.white24)),
          width: 3,
        ),
        boxShadow: data.isScrolling
            ? [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '${data.countdown}',
          style: TextStyle(
            color: data.isScrolling ? Colors.blue : Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildScrollPreview(List<double> predictions) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          const Text(
            "PREVIEW (AI)",
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: predictions
                .take(3)
                .map((p) => _buildPreviewItem(p))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewItem(double delay) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        "${delay.toStringAsFixed(1)}s",
        style: const TextStyle(color: Colors.white70, fontSize: 9),
      ),
    );
  }

  Widget _buildControlButtons(OverlayData data) {
    return Column(
      children: [
        IconButton(
          iconSize: 36,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            data.isPlaying
                ? Icons.pause_circle_filled
                : Icons.play_circle_filled,
            color: data.isPlaying
                ? (data.isAIEnabled ? Colors.blueAccent : Colors.orange)
                : Colors.green,
          ),
          onPressed: () {
            if (data.isPlaying) {
              _stopTimer();
            } else {
              _startTimer();
            }
          },
        ),
        // const SizedBox(height: 8),
        // IconButton(
        //   iconSize: 36,
        //   padding: EdgeInsets.zero,
        //   constraints: const BoxConstraints(),
        //   icon: Icon(
        //     Icons.skip_next,
        //     color: data.isScrolling ? Colors.blue : Colors.white70,
        //   ),
        //   onPressed: data.isScrolling ? null : _triggerScroll,
        // ),
      ],
    );
  }
}
