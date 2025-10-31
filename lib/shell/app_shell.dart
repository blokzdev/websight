import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'package:websight/ads/ads_controller.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/utils/helpers.dart';

class AppShell extends StatefulWidget {
  final WebSightConfig config;
  final Widget child;

  const AppShell({
    super.key,
    required this.config,
    required this.child,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
        length: widget.config.routes.length, vsync: this, initialIndex: 0);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final adsController = context.watch<AdsController>();
    final String location = GoRouterState.of(context).uri.toString();
    // Pass the context so the controller can get the screen width for adaptive ads.
    adsController.loadAdForRoute(location, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);
    final currentRoute = widget.config.routes[selectedIndex];
    final showAppBar = currentRoute.appbarVisible;
    final layoutStyle = widget.config.flutterUi.layout.scaffold;
    final adsController = context.watch<AdsController>();

    return Scaffold(
      appBar: showAppBar ? _buildAppBar(context, currentRoute) : null,
      body: Column(
        children: [
          _buildAdBanner(adsController, 'top'),
          Expanded(child: widget.child),
          _buildAdBanner(adsController, 'bottom'),
        ],
      ),
      drawer:
          layoutStyle == 'drawer' ? _buildDrawer(context, selectedIndex) : null,
      bottomNavigationBar: layoutStyle == 'bottom_tabs'
          ? _buildBottomNavigationBar(context, selectedIndex)
          : null,
      floatingActionButton: widget.config.flutterUi.layout.visible
          ? _buildFab(context)
          : null,
    );
  }

  Widget _buildAdBanner(AdsController adsController, String position) {
    return ValueListenableBuilder<BannerAd?>(
      valueListenable: adsController.currentBannerAd,
      builder: (context, ad, child) {
        if (ad != null && adsController.currentAdPosition == position) {
          return SafeArea(
            child: SizedBox(
              width: ad.size.width.toDouble(),
              height: ad.size.height.toDouble(),
              child: AdWidget(ad: ad),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  AppBar _buildAppBar(BuildContext context, RouteConfig currentRoute) {
    return AppBar(
      title: Text(currentRoute.title),
    );
  }

  Widget _buildDrawer(BuildContext context, int selectedIndex) {
    return Drawer(
        child: ListView(
      children: widget.config.routes
          .map((route) => ListTile(
                title: Text(route.title),
                onTap: () {
                  context.go(route.path);
                  Navigator.pop(context);
                },
              ))
          .toList(),
    ));
  }

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return BottomNavigationBar(
      items: widget.config.routes
          .map((route) => BottomNavigationBarItem(
                icon: Icon(iconForString(route.icon ?? '')),
                label: route.label,
              ))
          .toList(),
      currentIndex: selectedIndex,
      onTap: (index) => context.go(widget.config.routes[index].path),
    );
  }

  Widget _buildFab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () {},
      child: const Icon(Icons.add),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    final index =
        widget.config.routes.indexWhere((route) => route.path == location);
    return index < 0 ? 0 : index;
  }
}
