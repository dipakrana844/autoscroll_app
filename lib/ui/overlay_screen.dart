import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  int _countdown = 10;
  bool _isScrolling = false;
  bool _isPlaying = false;
  Timer? _timer;

  void _startTimer() {
    setState(() => _isPlaying = true);
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
    });
  }

  Future<void> _triggerScroll() async {
    setState(() => _isScrolling = true);
    // Use background service as a bridge to native side
    FlutterBackgroundService().invoke('trigger_scroll');
    debugPrint("Overlay: Sent trigger_scroll to background service");

    // Provide visual feedback for result
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      setState(() {
        _countdown = 10;
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
