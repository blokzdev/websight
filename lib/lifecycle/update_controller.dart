import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:websight/config/webview_config.dart';

/// Manages the in-app update flow.
class UpdateController {
  final WebSightConfig config;

  UpdateController({required this.config});

  /// Checks for an update and initiates the appropriate flow.
  Future<void> checkForUpdate() async {
    // Do nothing if the feature is disabled in the config.
    if (config.updates.inAppUpdates == 'none') {
      debugPrint('UpdateController: In-app updates are disabled.');
      return;
    }

    try {
      final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('UpdateController: Update available.');
        if (config.updates.inAppUpdates == 'flexible') {
          // Perform a flexible update
          await InAppUpdate.startFlexibleUpdate();
          // You can optionally complete the update when the user is ready.
          // For now, we'll let the system handle it.
        } else if (config.updates.inAppUpdates == 'immediate') {
          // Perform an immediate update
          await InAppUpdate.performImmediateUpdate();
        }
      } else {
        debugPrint('UpdateController: No update available.');
      }
    } catch (e) {
      debugPrint('UpdateController: Failed to check for updates: $e');
    }
  }
}
