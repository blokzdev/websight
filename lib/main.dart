import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:websight/ads/ads_controller.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/firebase_options.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/lifecycle/billing_controller.dart';
import 'package:websight/lifecycle/disclaimer_controller.dart';
import 'package:websight/lifecycle/fcm_controller.dart';
import 'package:websight/lifecycle/permissions_controller.dart';
import 'package:websight/lifecycle/rating_controller.dart';
import 'package:websight/lifecycle/system_chrome_controller.dart';
import 'package:websight/lifecycle/update_controller.dart';
import 'package:websight/shell/app_router.dart';
import 'package:websight/shell/disclaimer_gate.dart';
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

  // Apply the configured edge-to-edge / immersive system UI style as early
  // as we can — before runApp so the very first frame draws under the
  // transparent bars. Re-applied on theme-mode changes inside WebSightApp.
  final systemChrome = SystemChromeController(feature: features.systemUi);
  final initialBrightness =
      WidgetsBinding.instance.platformDispatcher.platformBrightness;
  final initialThemeBrightness = switch (config.flutterUi.theme.brightness) {
    'dark' => Brightness.dark,
    'light' => Brightness.light,
    _ => initialBrightness,
  };
  unawaited(systemChrome.applyForBrightness(initialThemeBrightness));

  final analytics = AnalyticsController(config: config);
  await analytics.initialize();

  final ads = AdsController(config: config);
  final updates = UpdateController(config: config);
  final permissions = PermissionsController(config: config);
  final fcm = FcmController(config: config);
  final billing = BillingController(feature: features.billing);
  final rating = RatingController(feature: features.rating);
  final disclaimer = DisclaimerController(
    feature: features.legal.unofficialDisclaimer,
  );

  // Fire-and-forget init flows — never block first frame.
  unawaited(ads.initialize());
  unawaited(updates.checkForUpdate());
  unawaited(permissions.initializeAndRequestPermissions());
  unawaited(fcm.initialize());
  unawaited(billing.initialize());
  unawaited(rating.maybePromptOnLaunch());
  unawaited(disclaimer.load());

  runApp(
    MultiProvider(
      providers: [
        Provider<WebSightConfig>.value(value: config),
        Provider<WebSightFeatures>.value(value: features),
        Provider<SystemChromeController>.value(value: systemChrome),
        // AnalyticsController is intentionally a plain Provider — it holds no
        // listeners, streams, or other resources that need disposal. The
        // FirebaseAnalytics / Crashlytics SDKs themselves manage their own
        // lifecycle. If we add per-instance state in the future (e.g. an opt-in
        // flag stream), promote this to ChangeNotifierProvider.
        Provider<AnalyticsController>.value(value: analytics),
        ChangeNotifierProvider<AdsController>.value(value: ads),
        ChangeNotifierProvider<FcmController>.value(value: fcm),
        ChangeNotifierProvider<BillingController>.value(value: billing),
        ChangeNotifierProvider<DisclaimerController>.value(value: disclaimer),
        ChangeNotifierProvider<WebViewSignals>(create: (_) => WebViewSignals()),
      ],
      child: const WebSightApp(),
    ),
  );
}

class WebSightApp extends StatefulWidget {
  const WebSightApp({super.key});

  @override
  State<WebSightApp> createState() => _WebSightAppState();
}

class _WebSightAppState extends State<WebSightApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // Re-apply system-bar icon brightness when the user toggles their
    // OS-level dark mode while the app is running. Only matters when
    // theme.brightness == 'system'; for explicit light/dark it's a no-op.
    if (!mounted) return;
    final config = context.read<WebSightConfig>();
    if (config.flutterUi.theme.brightness != 'system') return;
    final platformBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    unawaited(
      context.read<SystemChromeController>().applyForBrightness(
            platformBrightness,
          ),
    );
  }

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
      // Wrap every route in the disclaimer gate. When the feature is
      // disabled the gate is a transparent passthrough; when enabled it
      // shows the modal dialog on top of the routed child until the
      // user accepts (or declines + exits).
      builder: (context, child) =>
          DisclaimerGate(child: child ?? const SizedBox.shrink()),
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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
