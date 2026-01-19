import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'providers/settings_provider.dart';
import 'ui/main_screen.dart';
import 'ui/overlay_screen.dart';
import 'services/background_service_manager.dart';
import 'services/analytics_service.dart';
import 'services/preferences_service.dart';
import 'core/app_theme.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: OverlayScreen()),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  // Initialize services
  final serviceManager = BackgroundServiceManager();
  await serviceManager.initialize();
  serviceManager.listenForScrollOnMain();

  final analyticsService = AnalyticsService();
  await analyticsService.initialize(prefs);

  final preferencesService = PreferencesService();
  await preferencesService.initialize(prefs);

  // Track app opened
  analyticsService.logEvent(AnalyticsEvents.appOpened);
  preferencesService.updateLastActiveDate();

  // Native Bridge: Listen for App Changes (Target App Detection)
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
          analyticsService.logEvent(AnalyticsEvents.overlayShown);
        }
      } else {
        if (await FlutterOverlayWindow.isActive()) {
          await FlutterOverlayWindow.closeOverlay();
          analyticsService.logEvent(AnalyticsEvents.overlayHidden);
        }
      }
    }
    return null;
  });

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
      home: const MainScreen(),
    );
  }
}
