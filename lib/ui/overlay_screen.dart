import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int _countdown = 10;
  int _maxDuration = 10;
  bool _isScrolling = false;
  bool _isPlaying = false;
  Timer? _timer;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (event != null && event is Map) {
        if (event.containsKey('scrollDuration')) {
          final newDuration = event['scrollDuration'] as int;
          setState(() {
            _maxDuration = newDuration;
            if (!_isPlaying && !_isScrolling) {
              _countdown = _maxDuration;
            }
          });
        }
      }
    });
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _refreshDuration();
  }

  void _refreshDuration() {
    if (_prefs != null) {
      setState(() {
        _maxDuration =
            _prefs!.getInt(AppConstants.keyScrollDuration) ??
            AppConstants.defaultDuration;
        // If the timer isn't running, update the current display
        if (!_isPlaying && !_isScrolling) {
          _countdown = _maxDuration;
        }
      });
    }
  }

  void _startTimer() {
    // Refresh duration one last time before starting to be sure
    _refreshDuration();
    setState(() {
      _isPlaying = true;
      _countdown = _maxDuration;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
      _countdown = _maxDuration;
    });
  }

  Future<void> _triggerScroll() async {
    if (_isScrolling) return;

    setState(() => _isScrolling = true);

    try {
      // Revert optimization: Must use background service bridge because
      // the Overlay runs in a separate engine that lacks the custom plugin.
      FlutterBackgroundService().invoke('trigger_scroll');
      debugPrint("Overlay: Triggered scroll via Background Service bridge");
    } catch (e) {
      debugPrint("Overlay Scroll Error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      // Always re-read duration after a scroll finishes in case user changed it
      _refreshDuration();
      setState(() {
        _countdown = _maxDuration;
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
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 10, spreadRadius: 2),
          ],
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.drag_handle, color: Colors.white54, size: 20),
                const SizedBox(height: 10),
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
              : (_isPlaying ? Colors.orange : Colors.white24),
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
            color: _isPlaying ? Colors.orange : Colors.green,
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
