import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'scroll_service.dart';

enum ServiceState { stopped, starting, running, stopping, error }

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance =
      BackgroundServiceManager._internal();

  factory BackgroundServiceManager() => _instance;

  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  ServiceState _state = ServiceState.stopped;

  ServiceState get state => _state;

  Future<void> initialize(Function(ServiceInstance) callback) async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: callback,
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

  Future<bool> get isRunning async {
    final running = await _service.isRunning();
    _state = running ? ServiceState.running : ServiceState.stopped;
    return running;
  }

  Future<void> start() async {
    _state = ServiceState.starting;
    try {
      await _service.startService();
      _state = ServiceState.running;
    } catch (e) {
      _state = ServiceState.error;
      rethrow;
    }
  }

  void stop() {
    _state = ServiceState.stopping;
    _service.invoke('stopService');
    _state = ServiceState.stopped;
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
