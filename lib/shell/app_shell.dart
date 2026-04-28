import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import 'package:websight/ads/ads_controller.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/shell/action_dispatcher.dart';
import 'package:websight/shell/route_paths.dart';
import 'package:websight/shell/webview_signals.dart';
import 'package:websight/utils/helpers.dart';

/// The top-level scaffold around the routed `child`. All visual chrome —
/// AppBar actions, drawer, bottom tabs, FAB, ad placements — is sourced from
/// [WebSightConfig] + [WebSightFeatures].
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.config,
    required this.features,
    required this.child,
  });

  final WebSightConfig config;
  final WebSightFeatures features;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  /// Last route we asked the ads controller to load. We avoid retrigging
  /// `loadAdForRoute` on every rotation / theme change / MediaQuery
  /// re-emit — only on actual route transitions.
  String? _lastAdRoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ads = context.watch<AdsController>();
    final location = GoRouterState.of(context).uri.toString();
    if (_lastAdRoute != location) {
      _lastAdRoute = location;
      ads.loadAdForRoute(location, context: context);
    }
  }

  RouteConfig? _currentRoute(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (final r in widget.config.routes) {
      // The router was registered with go_router-style paths
      // (/web/item/:id), but config.routes still carries the YAML form
      // (/web/item/{id}). Convert before matching.
      final goPath = yamlPathToGoRouter(r.path);
      if (routeMatchesPattern(goPath, location)) return r;
    }
    return widget.config.routes.isNotEmpty ? widget.config.routes.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final layout = widget.config.flutterUi.layout.scaffold;
    final route = _currentRoute(context);
    final appbarVisible = route?.appbarVisible ?? true;
    final ads = context.watch<AdsController>();
    final signals = context.read<WebViewSignals>();
    final dispatcher = ActionDispatcher(
      onWebviewReload: signals.requestReload,
      onWebviewBack: signals.requestBack,
    );

    return Scaffold(
      appBar: appbarVisible ? _buildAppBar(context, route, dispatcher) : null,
      drawer: layout == 'drawer' && widget.features.drawer.visible
          ? _buildDrawer(context, dispatcher)
          : null,
      bottomNavigationBar:
          layout == 'bottom_tabs' && widget.features.bottomTabs.items.isNotEmpty
              ? _buildBottomNavigationBar(context)
              : null,
      floatingActionButton:
          widget.features.fab.visible ? _buildFab(context, dispatcher) : null,
      body: Column(
        children: [
          _buildAdBanner(ads, 'top'),
          Expanded(child: widget.child),
          _buildAdBanner(ads, 'bottom'),
        ],
      ),
    );
  }

  Widget _buildAdBanner(AdsController ads, String position) {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: ads.currentBannerAd,
      builder: (context, ad, _) {
        if (ad == null || ads.currentAdPosition != position) {
          return const SizedBox.shrink();
        }
        return SafeArea(
          top: position == 'top',
          bottom: position == 'bottom',
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    RouteConfig? route,
    ActionDispatcher dispatcher,
  ) {
    final actions = widget.config.flutterUi.layout.appbar.actions
        .map(
          (a) => IconButton(
            icon: Icon(iconForString(a.icon)),
            tooltip: a.id,
            onPressed: () => dispatcher.dispatch(context, a.action),
          ),
        )
        .toList(growable: false);

    return AppBar(
      title: Text(route?.title ?? widget.config.app.name),
      actions: actions,
    );
  }

  Drawer _buildDrawer(BuildContext context, ActionDispatcher dispatcher) {
    final d = widget.features.drawer;
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: theme.colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (d.avatarAsset != null && d.avatarAsset!.isNotEmpty)
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: AssetImage(d.avatarAsset!),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    d.headerTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  if (d.headerSubtitle != null)
                    Text(
                      d.headerSubtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                children: d.items
                    .map((i) => _drawerTile(context, i, dispatcher))
                    .toList(growable: false),
              ),
            ),
            if (d.footerItems.isNotEmpty) const Divider(height: 1),
            ...d.footerItems.map((i) => _drawerTile(context, i, dispatcher)),
          ],
        ),
      ),
    );
  }

  ListTile _drawerTile(
    BuildContext context,
    DrawerItem item,
    ActionDispatcher dispatcher,
  ) {
    return ListTile(
      leading: Icon(iconForString(item.icon)),
      title: Text(item.title),
      onTap: () {
        Navigator.of(context).pop();
        if (item.route != null && item.route!.isNotEmpty) {
          context.go(item.route!);
        } else if (item.action != null) {
          dispatcher.dispatch(context, item.action);
        }
      },
    );
  }

  BottomNavigationBar _buildBottomNavigationBar(BuildContext context) {
    final tabs = widget.features.bottomTabs.items;
    final location = GoRouterState.of(context).uri.toString();
    var index = tabs.indexWhere((t) => t.route == location);
    if (index < 0) index = widget.features.bottomTabs.initialIndex;
    if (index >= tabs.length) index = 0;
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: index,
      onTap: (i) => context.go(tabs[i].route),
      items: tabs
          .map(
            (t) => BottomNavigationBarItem(
              icon: Icon(iconForString(t.icon)),
              label: t.label,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildFab(BuildContext context, ActionDispatcher dispatcher) {
    final fab = widget.features.fab;
    return FloatingActionButton(
      onPressed: () => dispatcher.dispatch(context, fab.action),
      child: Icon(iconForString(fab.icon)),
    );
  }
}
