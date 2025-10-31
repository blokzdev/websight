import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/native_screens/alerts_screen.dart';
import 'package:websight/native_screens/portfolio_screen.dart';
import 'package:websight/native_screens/settings_screen.dart';
import 'package:websight/native_screens/watchlist_screen.dart';
import 'package:websight/shell/app_shell.dart';
import 'package:websight/webview/webview_screen.dart';

class AppRouter {
  final WebSightConfig config;
  final AnalyticsController analyticsController;
  late final GoRouter router;
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  AppRouter({required this.config, required this.analyticsController}) {
    final routes = config.routes.map((routeConfig) {
      return GoRoute(
        path: routeConfig.path,
        builder: (context, state) {
          if (routeConfig.kind == 'webview') {
            return WebViewScreen(
              initialUrl: routeConfig.url ?? config.app.homeUrl,
              routeConfig: routeConfig,
            );
          } else {
            return _nativeScreen(routeConfig.path);
          }
        },
      );
    }).toList();

    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/web/home',
      observers: [
        // This observer automatically logs screen_view events to Firebase Analytics.
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return AppShell(
              config: config, // Pass the config object directly.
              child: child,
            );
          },
          routes: routes,
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Text(
              'Error: ${state.error?.message ?? "The requested page could not be found."}'),
        ),
      ),
    );
  }

  Widget _nativeScreen(String path) {
    switch (path) {
      case '/native/watchlist':
        return const WatchlistScreen();
      case '/native/portfolio':
        return const PortfolioScreen();
      case '/native/alerts':
        return const AlertsScreen();
      case '/native/settings':
        return const SettingsScreen();
      default:
        return const Scaffold(
          body: Center(
            child: Text('Unknown Native Screen'),
          ),
        );
    }
  }
}
