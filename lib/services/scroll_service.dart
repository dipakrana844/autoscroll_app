import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/constants.dart';

class ScrollService {
  static const MethodChannel _channel = MethodChannel(
    AppConstants.scrollChannel,
  );

  static Future<bool> triggerScroll() async {
    try {
      debugPrint("ScrollService: Triggering scroll via MethodChannel");
      final bool result = await _channel.invokeMethod('scroll');
      return result;
    } catch (e) {
      debugPrint("ScrollService Error: $e");
      return false;
    }
  }

  static Future<bool> isAccessibilityServiceEnabled() async {
    try {
      final bool result = await _channel.invokeMethod('isServiceEnabled');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check service status: '${e.message}'.");
      return false;
    }
  }

  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      print("Failed to open accessibility settings: '${e.message}'.");
    }
  }
}
