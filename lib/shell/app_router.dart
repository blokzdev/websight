import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/analytics_controller.dart';
import 'package:websight/native_screens/configurable_native_screen.dart';
import 'package:websight/shell/app_shell.dart';
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
              path: _toGoRouterPath(r.path),
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
          return _stripPattern(r.path);
        }
      }
    }
    final webview = config.routes.firstWhere(
      (r) => r.kind == 'webview',
      orElse: () => config.routes.first,
    );
    return _stripPattern(webview.path);
  }

  /// Convert YAML-style `/web/item/{id}` into go_router `/web/item/:id`.
  String _toGoRouterPath(String path) {
    return path.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => ':${m.group(1)}');
  }

  /// Strip parameter placeholders so a path can be used as initialLocation.
  /// `/web/item/:id` becomes `/web/item` (best-effort; if there is no static
  /// prefix, returns the original).
  String _stripPattern(String path) {
    final i = path.indexOf(':');
    if (i < 0) return path;
    final base = path.substring(0, i).trimRight();
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  Widget _buildScreen(RouteConfig r, GoRouterState state) {
    if (r.kind == 'webview') {
      var url = r.url ?? config.app.homeUrl;
      // Substitute `{name}` tokens in the configured URL using path params.
      url = url.replaceAllMapped(
        RegExp(r'\{(\w+)\}'),
        (m) => state.pathParameters[m.group(1)!] ?? '',
      );
      return WebViewScreen(initialUrl: url, routeConfig: r);
    }
    return ConfigurableNativeScreen(route: r);
  }
}
