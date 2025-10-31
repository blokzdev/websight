import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:websight/config/webview_config.dart';

/// Manages analytics and crash reporting.
class AnalyticsController {
  final WebSightConfig config;

  AnalyticsController({required this.config});

  /// Initializes Firebase Analytics and Crashlytics.
  Future<void> initialize() async {
    if (config.analyticsCrash.analytics) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
      debugPrint('AnalyticsController: Firebase Analytics enabled.');
    } else {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      debugPrint('AnalyticsController: Firebase Analytics disabled.');
    }

    if (config.analyticsCrash.crashlytics) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      debugPrint('AnalyticsController: Firebase Crashlytics enabled.');
    } else {
      debugPrint('AnalyticsController: Firebase Crashlytics disabled.');
    }
  }

  /// Logs a screen view event.
  void logScreenView(String screenName) {
    if (config.analyticsCrash.analytics) {
      FirebaseAnalytics.instance.logScreenView(screenName: screenName);
    }
  }

  /// Logs a custom event.
  void logEvent(String name, {Map<String, Object>? parameters}) {
    if (config.analyticsCrash.analytics) {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: parameters);
    }
  }
}
