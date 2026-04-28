import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/fcm_controller.dart';
import 'package:websight/native_screens/configurable_native_screen.dart';

void main() {
  // A minimal config sufficient to render either variant. We deliberately
  // avoid touching the json_serializable model so these tests don't depend on
  // build_runner output being current.
  WebSightConfig _config(
      {String name = 'WebSightDemo', String host = 'flutter.dev'}) {
    return WebSightConfig(
      app: AppConfig(host: host, homeUrl: 'https://$host', name: name),
      flutterUi: FlutterUiConfig(
        theme: ThemeConfig(
          brightness: 'dark',
          primary: '#16A34A',
          useMaterial3: true,
        ),
        layout: LayoutConfig(
          scaffold: 'drawer',
          appbar: AppBarConfig(visible: true, actions: const <AppBarAction>[]),
          visible: false,
        ),
      ),
      routes: <RouteConfig>[
        RouteConfig(
          path: '/native/settings',
          kind: 'native',
          title: 'Settings',
          pullToRefresh: false,
          appbarVisible: true,
        ),
        RouteConfig(
          path: '/web/privacy',
          kind: 'webview',
          title: 'Privacy',
          url: 'https://$host/privacy',
          pullToRefresh: false,
          appbarVisible: true,
        ),
      ],
      navigation: NavigationConfig(
        externalAllowlist: const <String>[],
        deepLinks: DeepLinksConfig(enable: false, hosts: const <String>[]),
      ),
      security: SecurityConfig(restrictToHosts: <String>[host]),
      webviewSettings: WebViewSettings(
        javascriptEnabled: true,
        domStorageEnabled: true,
      ),
      jsBridge: JsBridgeConfig(
        enabled: false,
        name: 'WebSightBridge',
        methods: const <String>[],
        secureOriginOnly: true,
        inboundEvents: const <InboundEvent>[],
      ),
      ads: AdsConfig(
        enabled: false,
        consentGateWithUmp: false,
        placements: AdPlacements(
          globalBanner: null,
          routePlacements: const <String, AdPlacementConfig>{},
        ),
      ),
      behaviorOverrides: BehaviorOverridesConfig(
        backButton: BackButtonConfig(confirmBeforeExit: true),
      ),
      updates: UpdateConfig(inAppUpdates: 'none'),
      analyticsCrash: AnalyticsCrashConfig(analytics: true, crashlytics: true),
      notifications: NotificationsConfig(
        postNotificationsPermission: true,
        fcmEnabled: false,
      ),
    );
  }

  Widget _harness({
    required Widget child,
    required WebSightConfig config,
  }) {
    final features = WebSightFeatures.fromRaw(<String, dynamic>{
      'app': {'name': config.app.name},
    }, appName: config.app.name);
    return MultiProvider(
      providers: [
        Provider<WebSightConfig>.value(value: config),
        Provider<WebSightFeatures>.value(value: features),
        ChangeNotifierProvider<FcmController>(
          create: (_) => FcmController(config: config),
        ),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  testWidgets('settings variant shows app name and host from config',
      (tester) async {
    // The settings page renders many tiles in a ListView; the default
    // 800x600 test viewport doesn't fit all of them and ListView lazily
    // builds children, so off-screen tiles (Privacy, Rate this app, etc.)
    // never enter the widget tree. Pump a tall viewport instead.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final config = _config(name: 'MyShop', host: 'shop.example.com');
    final route = config.routes.first; // /native/settings

    await tester.pumpWidget(_harness(
      config: config,
      child: ConfigurableNativeScreen(route: route),
    ));

    expect(find.text('MyShop'), findsOneWidget);
    expect(find.text('shop.example.com'), findsOneWidget);
    expect(find.text('Privacy'), findsOneWidget); // surfaced from /web/privacy
    expect(find.text('Rate this app'), findsOneWidget);
  });

  testWidgets('placeholder variant labels the route path', (tester) async {
    final config = _config();
    final route = RouteConfig(
      path: '/native/watchlist',
      kind: 'native',
      title: 'Watchlist',
      icon: 'star',
      pullToRefresh: false,
      appbarVisible: true,
    );

    await tester.pumpWidget(_harness(
      config: config,
      child: ConfigurableNativeScreen(route: route),
    ));

    expect(find.text('Watchlist'), findsOneWidget);
    expect(
      find.textContaining('/native/watchlist'),
      findsOneWidget,
    );
  });
}
