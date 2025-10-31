import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:websight/ads/ads_controller.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/lifecycle/permissions_controller.dart';
import 'package:websight/lifecycle/update_controller.dart';
import 'package:websight/shell/app_router.dart';
import 'package:websight/theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:websight/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  final configResult = await WebSightConfig.loadAndValidate();

  if (configResult.report.errors.isNotEmpty &&
      configResult.config.app.host.isEmpty) {
    runApp(ErrorApp(report: configResult.report));
    return;
  }

  // Initialize controllers
  final analyticsController = AnalyticsController(config: configResult.config);
  await analyticsController.initialize();

  final adsController = AdsController(config: configResult.config);
  final updateController = UpdateController(config: configResult.config);
  final permissionsController =
      PermissionsController(config: configResult.config);

  // Start the async initialization flows.
  adsController.initialize();
  updateController.checkForUpdate();
  permissionsController.initializeAndRequestPermissions();

  runApp(
    MultiProvider(
      providers: [
        Provider<WebSightConfig>.value(value: configResult.config),
        Provider<AnalyticsController>.value(value: analyticsController),
        ChangeNotifierProvider<AdsController>.value(value: adsController),
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
    final appRouter = AppRouter(
        config: config,
        analyticsController: context.read<AnalyticsController>());
    final appTheme = AppTheme(config: config.flutterUi.theme);

    final themeMode = switch (config.flutterUi.theme.brightness) {
      'dark' => ThemeMode.dark,
      'light' => ThemeMode.light,
      _ => ThemeMode.system,
    };

    return MaterialApp.router(
      title: config.app.name,
      theme: appTheme.buildTheme(),
      darkTheme: appTheme.buildTheme(),
      themeMode: themeMode,
      routerConfig: appRouter.router,
      debugShowCheckedModeBanner: false,
    );
  }
}

/// A simple app to display critical configuration errors.
class ErrorApp extends StatelessWidget {
  final ConfigReport report;
  const ErrorApp({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Configuration Error'),
          backgroundColor: Colors.red,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView(
            children: [
              const Text(
                'Failed to load webview_config.yaml.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                  'Please fix the errors below and restart the application.'),
              const SizedBox(height: 20),
              Text(
                'Errors:\n- ${report.errors.join("\n- ")}',
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
