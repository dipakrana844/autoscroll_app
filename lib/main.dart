import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'providers/settings_provider.dart';
import 'ui/main_screen.dart';
import 'ui/overlay_screen.dart';
import 'services/scroll_service.dart';

import 'package:flutter_background_service/flutter_background_service.dart';

import 'package:flutter_background_service_android/flutter_background_service_android.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayScreen()),
  );
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
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

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
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

  // Background timer logic can go here
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeService();

  // Listen for scroll commands from the background service bridge
  // This listener runs in the MAIN isolate which has the native plugin.
  FlutterBackgroundService().on('scroll_on_main').listen((event) {
    debugPrint(
      "Main Isolate: Received scroll command, triggering native scroll...",
    );
    ScrollService.triggerScroll();
  });

  const channel = MethodChannel('com.example.autoscroll/scroll');
  channel.setMethodCallHandler((call) async {
    if (call.method == "onAppChanged") {
      final bool isTargetApp = call.arguments as bool;
      debugPrint("App changed: isTargetApp = $isTargetApp");

      if (isTargetApp) {
        if (!(await FlutterOverlayWindow.isActive())) {
          await FlutterOverlayWindow.showOverlay(
            enableDrag: true,
            overlayTitle: "AutoScroll Controls",
            overlayContent: "Managing your Reels",
            flag: OverlayFlag.defaultFlag,
            alignment: OverlayAlignment.centerRight,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.right,
            height: 800,
            width: 200,
          );
        }
      } else {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
        }
      }
    }
    return null;
  });

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutoScroll Proto',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}
