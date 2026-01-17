import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../providers/settings_provider.dart';
import '../services/scroll_service.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  bool _isOverlayPermissionGranted = false;
  bool _isAccessibilityPermissionGranted = false;
  bool _isNotificationPermissionGranted = false;
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    final overlayStatus = await FlutterOverlayWindow.isPermissionGranted();
    final accessibilityStatus =
        await ScrollService.isAccessibilityServiceEnabled();
    final notificationStatus = await Permission.notification.isGranted;
    final isRunning = await FlutterBackgroundService().isRunning();

    if (mounted) {
      setState(() {
        _isOverlayPermissionGranted = overlayStatus;
        _isAccessibilityPermissionGranted = accessibilityStatus;
        _isNotificationPermissionGranted = notificationStatus;
        _isServiceRunning = isRunning;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _isNotificationPermissionGranted = status.isGranted;
    });
  }

  Future<void> _requestOverlayPermission() async {
    final bool? status = await FlutterOverlayWindow.requestPermission();
    if (status == true) {
      setState(() {
        _isOverlayPermissionGranted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('AutoScroll Pro'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(),
                const SizedBox(height: 24),
                _buildActionData(),
                const SizedBox(height: 24),
                _buildSectionTitle("Configuration"),
                const SizedBox(height: 12),
                _buildSettingsCard(settings, settingsNotifier),
                const SizedBox(height: 24),
                _buildSectionTitle("Advanced Features"),
                const SizedBox(height: 12),
                _buildAdvancedSettingsCard(settings, settingsNotifier),
                const SizedBox(height: 24),
                _buildSectionTitle("System Permissions"),
                const SizedBox(height: 12),
                _buildPermissionCard(),
                const SizedBox(height: 80), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStatusHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      // decoration: BoxDecoration(
      //   color: Colors.white.withOpacity(0.05),
      //   borderRadius: BorderRadius.circular(20),
      //   border: Border.all(color: Colors.white10),
      // ),
      child: Center(
        child: Column(
          children: [
            Icon(
              _isServiceRunning
                  ? Icons.check_circle_outline
                  : Icons.power_settings_new,
              size: 60,
              color: _isServiceRunning ? Colors.greenAccent : Colors.white38,
            ),
            const SizedBox(height: 16),
            Text(
              _isServiceRunning ? "Active & Ready" : "Service Inactive",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isServiceRunning
                  ? "Open TikTok, Reels, or Shorts to start"
                  : "Turn on the service to begin",
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionData() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isServiceRunning
              ? [Colors.blue.withOpacity(0.8), Colors.purple.withOpacity(0.8)]
              : [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _isServiceRunning
                ? Colors.blue.withOpacity(0.3)
                : Colors.transparent,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isServiceRunning ? "Master Switch" : "Enable Service",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isServiceRunning ? "ON" : "OFF",
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Switch(
            value: _isServiceRunning,
            activeColor: Colors.white,
            activeTrackColor: Colors.white.withOpacity(0.3),
            onChanged: (value) async {
              final service = FlutterBackgroundService();
              if (value) {
                if (!_isNotificationPermissionGranted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please grant notification permission'),
                    ),
                  );
                  return;
                }
                await service.startService();
              } else {
                service.invoke('stopService');
              }

              // Visual feedback delay
              await Future.delayed(const Duration(milliseconds: 300));
              _checkPermissions();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(SettingsState settings, SettingsNotifier notifier) {
    return _buildGlassCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Scroll Interval',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              Text(
                '${settings.scrollDuration}s',
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.blueAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
              overlayColor: Colors.blueAccent.withOpacity(0.2),
            ),
            child: Slider(
              value: settings.scrollDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              onChanged: (value) {
                notifier.updateScrollDuration(value.toInt());
              },
              onChangeEnd: (value) {
                notifier.saveScrollDuration(value.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedSettingsCard(
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    return _buildGlassCard(
      child: Column(
        children: [
          // Random Variance Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Humanize (Random)',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Adds random +/- time check',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              Text(
                settings.randomVariance == 0
                    ? 'OFF'
                    : '+/- ${settings.randomVariance}s',
                style: TextStyle(
                  color: settings.randomVariance > 0
                      ? Colors.orangeAccent
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.orangeAccent,
              inactiveTrackColor: Colors.white10,
              thumbColor: Colors.white,
            ),
            child: Slider(
              value: settings.randomVariance.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              onChanged: (value) {
                notifier.updateRandomVariance(value.toInt());
              },
              onChangeEnd: (value) {
                notifier.saveRandomVariance(value.toInt());
              },
            ),
          ),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          // Sleep Timer Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sleep Timer',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              DropdownButton<int>(
                dropdownColor: const Color(0xFF16213E),
                value: settings.sleepTimerMinutes,
                style: const TextStyle(color: Colors.white),
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Disabled')),
                  DropdownMenuItem(value: 10, child: Text('10 mins')),
                  DropdownMenuItem(value: 30, child: Text('30 mins')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    notifier.saveSleepTimer(value);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    return _buildGlassCard(
      child: Column(
        children: [
          _buildPermissionTile(
            'Overlay',
            _isOverlayPermissionGranted,
            _requestOverlayPermission,
          ),
          const Divider(color: Colors.white10),
          _buildPermissionTile(
            'Accessibility',
            _isAccessibilityPermissionGranted,
            () => ScrollService.openAccessibilitySettings(),
          ),
          const Divider(color: Colors.white10),
          _buildPermissionTile(
            'Notification',
            _isNotificationPermissionGranted,
            _requestNotificationPermission,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile(
    String title,
    bool isGranted,
    VoidCallback onAction,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: isGranted
          ? const Icon(Icons.check_circle, color: Colors.greenAccent)
          : TextButton(onPressed: onAction, child: const Text('Allow')),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}
