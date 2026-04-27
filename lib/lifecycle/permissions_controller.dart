import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:websight/config/webview_config.dart';

/// Requests runtime permissions according to the YAML config. Only permissions
/// flagged in the config are prompted; the system also short-circuits the
/// request on platform versions where the permission is not gate-required
/// (e.g. POST_NOTIFICATIONS is auto-granted on API <= 32).
class PermissionsController {
  PermissionsController({required this.config});

  final WebSightConfig config;

  Future<void> initializeAndRequestPermissions() async {
    if (config.notifications.postNotificationsPermission) {
      await _request(Permission.notification, label: 'notification');
    }
    // Camera is only requested on first JS-bridge `scanBarcode` call to avoid
    // surprising users with a camera prompt on cold launch.
  }

  Future<void> _request(Permission permission, {required String label}) async {
    final status = await permission.request();
    if (kDebugMode) {
      debugPrint('PermissionsController: $label = $status');
    }
  }
}
