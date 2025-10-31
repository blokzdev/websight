import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:websight/config/webview_config.dart';

/// Manages runtime permission requests.
class PermissionsController {
  final WebSightConfig config;

  PermissionsController({required this.config});

  /// Initializes and requests permissions as defined in the config.
  Future<void> initializeAndRequestPermissions() async {
    // This check is currently in the YAML but not yet in the config models.
    // We will assume it's needed for now.
    // if (config.notifications.postNotificationsPermission) {
    await _requestNotificationPermission();
    // }
  }

  /// Requests permission to post notifications on Android 13+.
  Future<void> _requestNotificationPermission() async {
    // permission_handler automatically handles the platform check.
    // This will only ask on Android 13 (API 33) and above.
    final status = await Permission.notification.request();
    if (status.isGranted) {
      debugPrint('PermissionsController: Notification permission granted.');
    } else if (status.isDenied) {
      debugPrint('PermissionsController: Notification permission denied.');
    } else if (status.isPermanentlyDenied) {
      debugPrint(
          'PermissionsController: Notification permission permanently denied.');
      // Optionally, you could open app settings here.
    }
  }
}
