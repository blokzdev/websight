import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/native_screens/configurable_native_screen.dart';
import 'package:websight/shell/app_shell.dart';
import 'package:websight/shell/route_paths.dart';
import 'package:websight/webview/webview_screen.dart';

/// Builds the GoRouter from the YAML route table.
///
/// Routing rules:
///   * `kind: webview` → WebViewScreen with the route's `url`. `{param}`
///     placeholders in the URL are substituted from the matched go_router
///     params. The route path may include `:param` segments to participate
///     in matching (`/web/item/:id`).
///   * `kind: native`  → looks up the widget by path; unknown native
///     screens render a clear `Unknown Native Screen` placeholder.
class AppRouter {
  AppRouter({
    required this.config,
    required this.features,
    required this.analyticsController,
  }) {
    final shellRoutes = config.routes
        .map((r) => GoRoute(
              path: yamlPathToGoRouter(r.path),
              pageBuilder: (context, state) => NoTransitionPage(
                child: _buildScreen(r, state),
              ),
            ))
        .toList(growable: false);

    final initial = _resolveInitialLocation();

    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initial,
      observers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(
            config: config,
            features: features,
            child: child,
          ),
          routes: shellRoutes,
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Text(
            state.error?.message ?? 'The requested page could not be found.',
          ),
        ),
      ),
    );
  }

  final WebSightConfig config;
  final WebSightFeatures features;
  final AnalyticsController analyticsController;
  late final GoRouter router;

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  String _resolveInitialLocation() {
    if (config.routes.isEmpty) return '/';
    final home = config.app.homeUrl;
    if (home.isNotEmpty) {
      for (final r in config.routes) {
        if (r.kind == 'webview' && r.url == home) {
          return stripParameterizedTail(yamlPathToGoRouter(r.path));
        }
      }
    }
    final webview = config.routes.firstWhere(
      (r) => r.kind == 'webview',
      orElse: () => config.routes.first,
    );
    return stripParameterizedTail(yamlPathToGoRouter(webview.path));
  }

  Widget _buildScreen(RouteConfig r, GoRouterState state) {
    if (r.kind == 'webview') {
      final template = r.url ?? config.app.homeUrl;
      final url = substituteUrlParams(template, state.pathParameters);
      return WebViewScreen(initialUrl: url, routeConfig: r);
    }
    return ConfigurableNativeScreen(route: r);
  }
}
