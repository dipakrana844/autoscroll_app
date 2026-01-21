import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'scroll_service.dart';

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance =
      BackgroundServiceManager._internal();

  factory BackgroundServiceManager() => _instance;

  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize(Function(ServiceInstance) onStart) async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'autoscroll_service_v2',
        initialNotificationTitle: 'AutoScroll Running',
        initialNotificationContent: 'Tap to manage',
        foregroundServiceNotificationId: 999,
      ),
      iosConfiguration: IosConfiguration(),
    );
  }

  Future<bool> get isRunning => _service.isRunning();

  Future<void> start() async {
    await _service.startService();
  }

  void stop() {
    _service.invoke('stopService');
  }

  void listenForScrollOnMain() {
    _service.on('scroll_on_main').listen((event) {
      debugPrint(
        "Main Isolate: Received scroll command, triggering native scroll...",
      );
      ScrollService.triggerScroll();
    });
  }
}
