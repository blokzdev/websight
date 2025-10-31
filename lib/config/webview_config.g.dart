// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebSightConfig _$WebSightConfigFromJson(Map<String, dynamic> json) =>
    WebSightConfig(
      app: AppConfig.fromJson(json['app'] as Map<String, dynamic>),
      flutterUi:
          FlutterUiConfig.fromJson(json['flutter_ui'] as Map<String, dynamic>),
      routes: (json['routes'] as List<dynamic>)
          .map((e) => RouteConfig.fromJson(e as Map<String, dynamic>))
          .toList(),
      navigation:
          NavigationConfig.fromJson(json['navigation'] as Map<String, dynamic>),
      security:
          SecurityConfig.fromJson(json['security'] as Map<String, dynamic>),
      webviewSettings: WebViewSettings.fromJson(
          json['webviewSettings'] as Map<String, dynamic>),
      jsBridge:
          JsBridgeConfig.fromJson(json['jsBridge'] as Map<String, dynamic>),
      ads: AdsConfig.fromJson(json['ads'] as Map<String, dynamic>),
      behaviorOverrides: BehaviorOverridesConfig.fromJson(
          json['behavior_overrides'] as Map<String, dynamic>),
      updates: UpdateConfig.fromJson(json['updates'] as Map<String, dynamic>),
      analyticsCrash: AnalyticsCrashConfig.fromJson(
          json['analytics_crash'] as Map<String, dynamic>),
      notifications: NotificationsConfig.fromJson(
          json['notifications'] as Map<String, dynamic>),
    );

AppConfig _$AppConfigFromJson(Map<String, dynamic> json) => AppConfig(
      host: json['host'] as String,
      homeUrl: json['homeUrl'] as String,
      name: json['name'] as String,
    );

FlutterUiConfig _$FlutterUiConfigFromJson(Map<String, dynamic> json) =>
    FlutterUiConfig(
      theme: ThemeConfig.fromJson(json['theme'] as Map<String, dynamic>),
      layout: LayoutConfig.fromJson(json['layout'] as Map<String, dynamic>),
    );

ThemeConfig _$ThemeConfigFromJson(Map<String, dynamic> json) => ThemeConfig(
      brightness: json['brightness'] as String,
      primary: json['primary'] as String,
      surface: json['surface'] as String?,
      onSurface: json['onSurface'] as String?,
      useMaterial3: json['useMaterial3'] as bool,
      fontFamily: json['fontFamily'] as String?,
    );

LayoutConfig _$LayoutConfigFromJson(Map<String, dynamic> json) => LayoutConfig(
      scaffold: json['scaffold'] as String,
      appbar: AppBarConfig.fromJson(json['appbar'] as Map<String, dynamic>),
      visible: json['visible'] as bool? ?? false,
    );

AppBarConfig _$AppBarConfigFromJson(Map<String, dynamic> json) => AppBarConfig(
      visible: json['visible'] as bool,
      actions: (json['actions'] as List<dynamic>)
          .map((e) => AppBarAction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

AppBarAction _$AppBarActionFromJson(Map<String, dynamic> json) => AppBarAction(
      id: json['id'] as String,
      icon: json['icon'] as String,
      action: json['action'] as String,
    );

RouteConfig _$RouteConfigFromJson(Map<String, dynamic> json) => RouteConfig(
      path: json['path'] as String,
      kind: json['kind'] as String,
      title: json['title'] as String,
      url: json['url'] as String?,
      pullToRefresh: json['pull_to_refresh'] as bool? ?? false,
      appbarVisible: json['appbar_visible'] as bool? ?? true,
      icon: json['icon'] as String?,
      label: json['label'] as String?,
    );

NavigationConfig _$NavigationConfigFromJson(Map<String, dynamic> json) =>
    NavigationConfig(
      externalAllowlist: (json['externalAllowlist'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      deepLinks:
          DeepLinksConfig.fromJson(json['deepLinks'] as Map<String, dynamic>),
    );

DeepLinksConfig _$DeepLinksConfigFromJson(Map<String, dynamic> json) =>
    DeepLinksConfig(
      enable: json['enable'] as bool,
      hosts: (json['hosts'] as List<dynamic>).map((e) => e as String).toList(),
    );

SecurityConfig _$SecurityConfigFromJson(Map<String, dynamic> json) =>
    SecurityConfig(
      restrictToHosts: (json['restrictToHosts'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

WebViewSettings _$WebViewSettingsFromJson(Map<String, dynamic> json) =>
    WebViewSettings(
      javascriptEnabled: json['javascriptEnabled'] as bool,
      domStorageEnabled: json['domStorageEnabled'] as bool,
    );

JsBridgeConfig _$JsBridgeConfigFromJson(Map<String, dynamic> json) =>
    JsBridgeConfig(
      enabled: json['enabled'] as bool,
      name: json['name'] as String,
      methods:
          (json['methods'] as List<dynamic>).map((e) => e as String).toList(),
      secureOriginOnly: json['secureOriginOnly'] as bool,
      inboundEvents: (json['inboundEvents'] as List<dynamic>)
          .map((e) => InboundEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

InboundEvent _$InboundEventFromJson(Map<String, dynamic> json) => InboundEvent(
      event: json['event'] as String,
      args: (json['args'] as List<dynamic>).map((e) => e as String).toList(),
      action: json['action'] as String,
    );

AdsConfig _$AdsConfigFromJson(Map<String, dynamic> json) => AdsConfig(
      enabled: json['enabled'] as bool,
      consentGateWithUmp: json['consent_gate_with_ump'] as bool,
      placements:
          AdPlacements.fromJson(json['placements'] as Map<String, dynamic>),
    );

AdPlacements _$AdPlacementsFromJson(Map<String, dynamic> json) => AdPlacements(
      globalBanner: json['global_banner'] == null
          ? null
          : AdPlacementConfig.fromJson(
              json['global_banner'] as Map<String, dynamic>),
      routePlacements: AdPlacements._placementsFromJson(
          json['route_placements'] as Map<String, dynamic>),
    );

AdPlacementConfig _$AdPlacementConfigFromJson(Map<String, dynamic> json) =>
    AdPlacementConfig(
      screenScope: json['screen_scope'] as String,
      route: json['route'] as String?,
      format: json['format'] as String,
      position: json['position'] as String,
      adUnitId: json['ad_unit_id'] as String,
    );

BehaviorOverridesConfig _$BehaviorOverridesConfigFromJson(
        Map<String, dynamic> json) =>
    BehaviorOverridesConfig(
      backButton: BackButtonConfig.fromJson(
          json['back_button'] as Map<String, dynamic>),
    );

BackButtonConfig _$BackButtonConfigFromJson(Map<String, dynamic> json) =>
    BackButtonConfig(
      confirmBeforeExit: json['confirm_before_exit'] as bool,
    );

UpdateConfig _$UpdateConfigFromJson(Map<String, dynamic> json) => UpdateConfig(
      inAppUpdates: json['in_app_updates'] as String,
    );

AnalyticsCrashConfig _$AnalyticsCrashConfigFromJson(
        Map<String, dynamic> json) =>
    AnalyticsCrashConfig(
      analytics: json['analytics'] as bool,
      crashlytics: json['crashlytics'] as bool,
    );

NotificationsConfig _$NotificationsConfigFromJson(Map<String, dynamic> json) =>
    NotificationsConfig(
      postNotificationsPermission:
          json['post_notifications_permission'] as bool,
      fcmEnabled: json['fcm_enabled'] as bool,
    );
