import 'package:flutter/material.dart';
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

    setState(() {
      _isOverlayPermissionGranted = overlayStatus;
      _isAccessibilityPermissionGranted = accessibilityStatus;
      _isNotificationPermissionGranted = notificationStatus;
      _isServiceRunning = isRunning;
    });
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
      appBar: AppBar(
        title: const Text('AutoScroll Prototype'),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPermissionCard(),
            const SizedBox(height: 24),
            _buildServiceCard(),
            const SizedBox(height: 24),
            _buildControlCard(), // Moved up for better visibility
            const SizedBox(height: 24),
            _buildSettingsCard(settings, settingsNotifier),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permissions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              title: const Text('Overlay Permission'),
              subtitle: Text(
                _isOverlayPermissionGranted ? 'Granted' : 'Required',
              ),
              trailing: _isOverlayPermissionGranted
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: _requestOverlayPermission,
                      child: const Text('Grant'),
                    ),
            ),
            ListTile(
              title: const Text('Accessibility Service'),
              subtitle: Text(
                _isAccessibilityPermissionGranted ? 'Enabled' : 'Disabled',
              ),
              trailing: _isAccessibilityPermissionGranted
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: () async {
                        await ScrollService.openAccessibilitySettings();
                      },
                      child: const Text('Enable'),
                    ),
            ),
            ListTile(
              title: const Text('Notification Permission'),
              subtitle: Text(
                _isNotificationPermissionGranted ? 'Granted' : 'Required',
              ),
              trailing: _isNotificationPermissionGranted
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: _requestNotificationPermission,
                      child: const Text('Grant'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Background Service',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ListTile(
              title: const Text('Status'),
              subtitle: Text(_isServiceRunning ? 'Running' : 'Stopped'),
              trailing: Switch(
                value: _isServiceRunning,
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

                  // Wait a bit for service to update
                  await Future.delayed(const Duration(milliseconds: 500));
                  _checkPermissions();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(SettingsState settings, SettingsNotifier notifier) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const SizedBox(height: 8),
            Text('Scroll Duration: ${settings.scrollDuration} seconds'),
            Slider(
              value: settings.scrollDuration.toDouble(),
              min: 5,
              max: 60,
              divisions: 11,
              label: '${settings.scrollDuration}s',
              onChanged: (value) {
                notifier.updateScrollDuration(value.toInt());
              },
              onChangeEnd: (value) {
                notifier.saveScrollDuration(value.toInt());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard() {
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              'Overlay Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                try {
                  bool isActive = await FlutterOverlayWindow.isActive();
                  if (isActive) {
                    await FlutterOverlayWindow.closeOverlay();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Overlay Closed')),
                      );
                    }
                  } else {
                    if (_isOverlayPermissionGranted) {
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
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Attempting to show overlay...'),
                          ),
                        );
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please grant overlay permission first',
                          ),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  debugPrint("Overlay Error: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
                setState(() {});
              },
              icon: const Icon(Icons.layers),
              label: const Text('Toggle Overlay Controls'),
            ),
            const SizedBox(height: 12),
            const Text(
              'NEW: The overlay now shows AUTOMATICALLY when you open Instagram Reels or YouTube Shorts, and hides when you leave them.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.greenAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Note: Ensure Accessibility Service is enabled for this to work.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
