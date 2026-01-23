import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import '../services/analytics_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int _countdown = 10;
  int _baseDuration = 10; // Stores the user setting
  int _randomVariance = 0;
  int _sleepTimerMinutes = 0;
  DateTime? _startTime;
  bool _isScrolling = false;
  bool _isPlaying = false;
  Timer? _timer;
  SharedPreferences? _prefs;

  bool _isAIEnabled = false;
  double _aiDelay = 10.0;
  double _aiConfidence = 0.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        bool needsUpdate = false;
        if (event.containsKey('scrollDuration')) {
          _baseDuration = event['scrollDuration'] as int;
          needsUpdate = true;
        }
        if (event.containsKey('randomVariance')) {
          _randomVariance = event['randomVariance'] as int;
        }
        if (event.containsKey('sleepTimerMinutes')) {
          _sleepTimerMinutes = event['sleepTimerMinutes'] as int;
        }
        if (event.containsKey('isAIAttentionModeEnabled')) {
          _isAIEnabled = event['isAIAttentionModeEnabled'] as bool;
          needsUpdate = true;
        }
        if (event.containsKey('aiSuggestedDelay')) {
          _aiDelay = (event['aiSuggestedDelay'] as num).toDouble();
          needsUpdate = true;
        }
        if (event.containsKey('aiConfidence')) {
          _aiConfidence = (event['aiConfidence'] as num).toDouble();
        }

        if (needsUpdate && !_isPlaying && !_isScrolling) {
          setState(() {
            _resetCountdown();
          });
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _refreshSettings();
  }

  void _refreshSettings() {
    if (_prefs != null) {
      setState(() {
        _baseDuration =
            _prefs!.getInt(AppConstants.keyScrollDuration) ??
            AppConstants.defaultDuration;
        _randomVariance =
            _prefs!.getInt(AppConstants.keyRandomVariance) ??
            AppConstants.defaultVariance;
        _sleepTimerMinutes =
            _prefs!.getInt(AppConstants.keySleepTimerMinutes) ??
            AppConstants.defaultSleepTimer;
        _isAIEnabled =
            _prefs!.getBool(AppConstants.keyEnableAIAttentionMode) ?? false;

        // If the timer isn't running, update the current display
        if (!_isPlaying && !_isScrolling) {
          _resetCountdown();
        }
      });
    }
  }

  void _resetCountdown() {
    int targetDuration = _baseDuration;

    if (_isAIEnabled) {
      targetDuration = _aiDelay.round();
    }

    if (_randomVariance > 0) {
      final random = Random();
      // Variance range: [-variance, +variance]
      final variance =
          random.nextInt(_randomVariance * 2 + 1) - _randomVariance;
      _countdown = max(3, targetDuration + variance); // Minimum 3 seconds
    } else {
      _countdown = targetDuration;
    }
  }

  void _startTimer() {
    _refreshSettings();
    setState(() {
      _isPlaying = true;
      _startTime = DateTime.now();
      _resetCountdown();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // Check Sleep Timer
      if (_sleepTimerMinutes > 0 && _startTime != null) {
        final elapsed = DateTime.now().difference(_startTime!);
        if (elapsed.inMinutes >= _sleepTimerMinutes) {
          _stopTimer();
          return;
        }
      }

      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        _triggerScroll();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _isPlaying = false;
      _startTime = null; // Reset session start time
      _resetCountdown();
    });
  }

  Future<void> _triggerScroll() async {
    if (_isScrolling) return;

    setState(() => _isScrolling = true);

    try {
      final service = FlutterBackgroundService();
      service.invoke('trigger_scroll');

      // Delegate logging to the main/background isolate to ensure consistency
      service.invoke('log_event', {'name': AnalyticsEvents.scrollTriggered});

      debugPrint("Overlay: Triggered scroll via Background Service bridge");

      // We handled scroll count in the main isolate now via the 'log_event' or 'scroll_on_main' handler
      // to avoid race conditions on SharedPreferences.
      // But if we want to update the UI immediately/locally we might need to keep it,
      // OR better: rely on the stream update.
      // For now, let's keep local increment if it's just for stats, but really
      // we should move this logic to the main app event handler too.
      // _prefsService.incrementScrollCount(); // Handled in main isolate now
    } catch (e) {
      debugPrint("Overlay Scroll Error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      // Refresh settings in case they changed
      _refreshSettings();
      setState(() {
        if (_isPlaying) {
          _resetCountdown();
        } else {
          _countdown = _isAIEnabled ? _aiDelay.round() : _baseDuration;
        }
        _isScrolling = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle, color: Colors.white54, size: 20),
                const SizedBox(height: 5),
                if (_isAIEnabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blueAccent, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.blueAccent,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "${(_aiConfidence * 100).toInt()}%",
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                _buildCountdownIndicator(),
                const SizedBox(height: 15),
                _buildControlButtons(),
                const SizedBox(height: 10),
                Text(
                  _isScrolling ? "SCROLLING..." : "NEXT",
                  style: TextStyle(
                    color: _isScrolling ? Colors.blue : Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownIndicator() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _isScrolling
              ? Colors.blue
              : (_isAIEnabled
                    ? Colors.blueAccent
                    : (_isPlaying ? Colors.orange : Colors.white24)),
          width: 3,
        ),
        boxShadow: _isScrolling
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
          '$_countdown',
          style: TextStyle(
            color: _isScrolling ? Colors.blue : Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Column(
      children: [
        IconButton(
          iconSize: 32,
          icon: Icon(
            _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: _isPlaying
                ? (_isAIEnabled ? Colors.blueAccent : Colors.orange)
                : Colors.green,
          ),
          onPressed: () {
            if (_isPlaying) {
              _stopTimer();
            } else {
              _startTimer();
            }
          },
        ),
        IconButton(
          iconSize: 32,
          icon: Icon(
            Icons.skip_next,
            color: _isScrolling ? Colors.blue : Colors.white70,
          ),
          onPressed: _isScrolling ? null : _triggerScroll,
        ),
      ],
    );
  }
}
