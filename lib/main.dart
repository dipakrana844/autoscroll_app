import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'providers/settings_provider.dart';
import 'ui/main_screen.dart';
import 'ui/overlay_screen.dart';
import 'services/background_service_manager.dart';
import 'services/analytics_service.dart';
import 'services/preferences_service.dart';
import 'services/attention_engine.dart';
import 'providers/attention_mode_provider.dart';
import 'core/app_theme.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayScreen()),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  debugPrint("Background Isolate: onStart triggered");
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
    service.invoke('scroll_on_main');
  });

  // Forward analytics events from Overlay to Main Isolate
  service.on('log_event').listen((event) {
    if (event != null) {
      service.invoke('log_event_on_main', event);
    }
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize services
  final serviceManager = BackgroundServiceManager();
  await serviceManager.initialize(onStart);
  serviceManager.listenForScrollOnMain();

  final analyticsService = AnalyticsService();
  await analyticsService.initialize(prefs);

  final preferencesService = PreferencesService();
  await preferencesService.initialize(prefs);

  final attentionEngine = AttentionEngine();
  await attentionEngine.initialize(prefs);

  // Track app opened
  analyticsService.logEvent(AnalyticsEvents.appOpened);
  preferencesService.updateLastActiveDate();

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
      title: 'AutoScroll Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const NativeEventsListener(child: MainScreen()),
    );
  }
}

class NativeEventsListener extends ConsumerStatefulWidget {
  final Widget child;
  const NativeEventsListener({super.key, required this.child});

  @override
  ConsumerState<NativeEventsListener> createState() =>
      _NativeEventsListenerState();
}

class _NativeEventsListenerState extends ConsumerState<NativeEventsListener> {
  static const _channel = MethodChannel('com.example.autoscroll/scroll');
  DateTime _lastScrollTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleMethodCall);
    _setupBackgroundListeners();
  }

  void _setupBackgroundListeners() {
    final service = FlutterBackgroundService();

    // Listen for scroll events triggered by Overlay
    service.on('scroll_on_main').listen((event) {
      final now = DateTime.now();
      final duration = now.difference(_lastScrollTime);
      _lastScrollTime = now;

      // Update AI Attention Model
      ref
          .read(attentionModeProvider.notifier)
          .recordScroll(success: true, duration: duration);

      // Increment Scroll Count locally
      PreferencesService().incrementScrollCount();
    });

    // Listen for analytics events from Overlay
    service.on('log_event_on_main').listen((event) {
      if (event != null && event is Map) {
        final name = event['name'] as String?;
        final params = event['parameters'] as Map<dynamic, dynamic>?;

        if (name != null) {
          final cleanParams = params?.map(
            (key, value) => MapEntry(key.toString(), value),
          );
          AnalyticsService().logEvent(name, parameters: cleanParams);
        }
      }
    });
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == "onAppChanged") {
      final args = call.arguments;
      bool isTargetApp = false;
      String packageName = "";
      bool isMusicActive = false;

      if (args is Map) {
        isTargetApp = args['isTargetApp'] ?? false;
        packageName = args['packageName'] ?? "";
        isMusicActive = args['isMusicActive'] ?? false;
      } else if (args is bool) {
        // Fallback for backward compatibility
        isTargetApp = args;
      }

      // Update Attention Mode Context
      ref
          .read(attentionModeProvider.notifier)
          .updateContext(
            packageName: packageName,
            isAudioActive: isMusicActive,
          );

      final analytics = AnalyticsService(); // Singleton

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
          analytics.logEvent(AnalyticsEvents.overlayShown);
        }
      } else {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
          analytics.logEvent(AnalyticsEvents.overlayHidden);
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
