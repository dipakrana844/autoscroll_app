import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'scroll_service.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Listen for scroll commands from the overlay
  service.on('trigger_scroll').listen((event) {
    // Forward the command to the Main Isolate (UI Isolate)
    // because that's where the native plugin is registered.
    service.invoke('scroll_on_main');
  });
}

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance =
      BackgroundServiceManager._internal();

  factory BackgroundServiceManager() => _instance;

  BackgroundServiceManager._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
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
