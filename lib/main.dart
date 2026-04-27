import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:websight/ads/ads_controller.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/firebase_options.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/lifecycle/billing_controller.dart';
import 'package:websight/lifecycle/fcm_controller.dart';
import 'package:websight/lifecycle/permissions_controller.dart';
import 'package:websight/lifecycle/rating_controller.dart';
import 'package:websight/lifecycle/update_controller.dart';
import 'package:websight/shell/app_router.dart';
import 'package:websight/shell/webview_signals.dart';
import 'package:websight/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final result = await WebSightConfig.loadAndValidate();
  if (result.report.errors.isNotEmpty && result.config.app.host.isEmpty) {
    runApp(ErrorApp(report: result.report));
    return;
  }

  final config = result.config;
  final features = WebSightFeatures.fromRaw(
    config.raw,
    appName: config.app.name,
  );

  final analytics = AnalyticsController(config: config);
  await analytics.initialize();

  final ads = AdsController(config: config);
  final updates = UpdateController(config: config);
  final permissions = PermissionsController(config: config);
  final fcm = FcmController(config: config);
  final billing = BillingController(feature: features.billing);
  final rating = RatingController(feature: features.rating);

  // Fire-and-forget init flows — never block first frame.
  unawaited(ads.initialize());
  unawaited(updates.checkForUpdate());
  unawaited(permissions.initializeAndRequestPermissions());
  unawaited(fcm.initialize());
  unawaited(billing.initialize());
  unawaited(rating.maybePromptOnLaunch());

  runApp(
    MultiProvider(
      providers: [
        Provider<WebSightConfig>.value(value: config),
        Provider<WebSightFeatures>.value(value: features),
        Provider<AnalyticsController>.value(value: analytics),
        ChangeNotifierProvider<AdsController>.value(value: ads),
        ChangeNotifierProvider<FcmController>.value(value: fcm),
        ChangeNotifierProvider<BillingController>.value(value: billing),
        ChangeNotifierProvider<WebViewSignals>(create: (_) => WebViewSignals()),
      ],
      child: const WebSightApp(),
    ),
  );
}

class WebSightApp extends StatelessWidget {
  const WebSightApp({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<WebSightConfig>();
    final features = context.read<WebSightFeatures>();
    final router = AppRouter(
      config: config,
      features: features,
      analyticsController: context.read<AnalyticsController>(),
    );
    final theme = AppTheme(config: config.flutterUi.theme);

    final mode = switch (config.flutterUi.theme.brightness) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: config.app.name,
      theme: theme.buildTheme(),
      darkTheme: theme.buildTheme(),
      themeMode: mode,
      routerConfig: router.router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key, required this.report});

  final ConfigReport report;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration Error'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              const Text(
                'Failed to load assets/webview_config.yaml.',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text('Fix the errors below and restart the application.'),
              const SizedBox(height: 20),
              Text(
                'Errors:\n- ${report.errors.join('\n- ')}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
