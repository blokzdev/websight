import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:websight/config/webview_config.dart';

/// Wraps Firebase Cloud Messaging behind a simple controller so the rest of
/// the app does not depend on the SDK directly. Only initialized when
/// `notifications.fcm_enabled` is true in the YAML config.
///
/// Foreground messages and notification taps are exposed as broadcast streams
/// so a WebView screen can forward them to the JS layer via
/// `WebSightBridge.onPush(detail)`.
class FcmController extends ChangeNotifier {
  FcmController({required this.config});

  final WebSightConfig config;
  final List<RemoteMessage> _inbox = <RemoteMessage>[];
  String? _token;
  bool _initialized = false;

  String? get token => _token;
  List<RemoteMessage> get inbox => List<RemoteMessage>.unmodifiable(_inbox);
  bool get initialized => _initialized;

  Future<void> initialize() async {
    if (_initialized || !config.notifications.fcmEnabled) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _token = await messaging.getToken();
      messaging.onTokenRefresh.listen((t) {
        _token = t;
        notifyListeners();
      });

      FirebaseMessaging.onMessage.listen(_onForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpenedApp);

      // Cold-start: handle a message that launched the app.
      final initial = await messaging.getInitialMessage();
      if (initial != null) _inbox.add(initial);
      _initialized = true;
      notifyListeners();
    } catch (e, st) {
      if (kDebugMode) debugPrint('FcmController init failed: $e\n$st');
    }
  }

  void _onForegroundMessage(RemoteMessage msg) {
    _inbox.add(msg);
    notifyListeners();
  }

  void _onMessageOpenedApp(RemoteMessage msg) {
    _inbox.add(msg);
    notifyListeners();
  }
}
