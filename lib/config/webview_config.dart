import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:json_annotation/json_annotation.dart';
import 'package:yaml/yaml.dart';

part 'webview_config.g.dart';

// Top-level configuration class
@JsonSerializable(createToJson: false)
class WebSightConfig {
  final AppConfig app;
  @JsonKey(name: 'flutter_ui')
  final FlutterUiConfig flutterUi;
  final List<RouteConfig> routes;
  final NavigationConfig navigation;
  final SecurityConfig security;
  final WebViewSettings webviewSettings;
  final JsBridgeConfig jsBridge;
  final AdsConfig ads;
  @JsonKey(name: 'behavior_overrides')
  final BehaviorOverridesConfig behaviorOverrides;
  final UpdateConfig updates;
  @JsonKey(name: 'analytics_crash')
  final AnalyticsCrashConfig analyticsCrash;
  final NotificationsConfig notifications;

  WebSightConfig({
    required this.app,
    required this.flutterUi,
    required this.routes,
    required this.navigation,
    required this.security,
    required this.webviewSettings,
    required this.jsBridge,
    required this.ads,
    required this.behaviorOverrides,
    required this.updates,
    required this.analyticsCrash,
    required this.notifications,
  });

  factory WebSightConfig.fromJson(Map<String, dynamic> json) =>
      _$WebSightConfigFromJson(json);

  /// Raw decoded YAML map. Keeps a reference so feature controllers (FCM,
  /// IAP, splash, offline, etc.) can pull optional configuration sections
  /// without forcing every YAML key through the json_serializable model.
  Map<String, dynamic>? _raw;
  Map<String, dynamic> get raw => _raw ?? const <String, dynamic>{};

  static Future<ConfigValidationResult> loadAndValidate() async {
    final report = ConfigReport();
    try {
      final yamlString =
          await rootBundle.loadString('assets/webview_config.yaml');
      final yamlMap = loadYaml(yamlString) as YamlMap;
      final jsonMap = json.decode(json.encode(yamlMap)) as Map<String, dynamic>;
      // Some YAML files wrap the spec under a top-level "webview_config" key.
      final root = (jsonMap['webview_config'] is Map<String, dynamic>)
          ? jsonMap['webview_config'] as Map<String, dynamic>
          : jsonMap;

      final config = WebSightConfig.fromJson(root).._raw = root;
      report.log('Configuration loaded and parsed successfully.');
      return ConfigValidationResult(config: config, report: report);
    } catch (e, s) {
      report.errors.add('Failed to load or parse config: $e\n$s');
      debugPrint(report.toString());
      return ConfigValidationResult(
          config: WebSightConfig.fallback(), report: report);
    }
  }

  factory WebSightConfig.fallback() {
    return WebSightConfig(
      app:
          AppConfig(host: '', homeUrl: 'about:blank', name: 'WebSight (Error)'),
      flutterUi: FlutterUiConfig(
        theme: ThemeConfig(
            brightness: 'light', primary: '#0000FF', useMaterial3: true),
        layout: LayoutConfig(
            scaffold: 'none',
            appbar: AppBarConfig(visible: false, actions: []),
            visible: false),
      ),
      routes: [],
      navigation: NavigationConfig(
          externalAllowlist: [],
          deepLinks: DeepLinksConfig(enable: false, hosts: [])),
      security: SecurityConfig(restrictToHosts: []),
      webviewSettings:
          WebViewSettings(javascriptEnabled: false, domStorageEnabled: false),
      jsBridge: JsBridgeConfig(
          enabled: false,
          name: '',
          methods: [],
          secureOriginOnly: true,
          inboundEvents: []),
      ads: AdsConfig(
          enabled: false,
          consentGateWithUmp: false,
          placements: AdPlacements(routePlacements: const {})),
      behaviorOverrides: BehaviorOverridesConfig(
          backButton: BackButtonConfig(confirmBeforeExit: true)),
      updates: UpdateConfig(inAppUpdates: 'none'),
      analyticsCrash:
          AnalyticsCrashConfig(analytics: false, crashlytics: false),
      notifications: NotificationsConfig(
          postNotificationsPermission: false, fcmEnabled: false),
    );
  }
}

class ConfigValidationResult {
  final WebSightConfig config;
  final ConfigReport report;
  ConfigValidationResult({required this.config, required this.report});
}

class ConfigReport {
  final List<String> fixes = [];
  final List<String> warnings = [];
  final List<String> errors = [];
  final StringBuffer _logBuffer = StringBuffer();

  void log(String message) {
    _logBuffer.writeln(message);
  }

  @override
  String toString() => _logBuffer.toString();
}

// Sub-models matching the YAML structure
@JsonSerializable(createToJson: false)
class AppConfig {
  final String host;
  final String homeUrl;
  final String name;
  AppConfig({required this.host, required this.homeUrl, required this.name});
  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class FlutterUiConfig {
  final ThemeConfig theme;
  final LayoutConfig layout;
  FlutterUiConfig({required this.theme, required this.layout});
  factory FlutterUiConfig.fromJson(Map<String, dynamic> json) =>
      _$FlutterUiConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class ThemeConfig {
  final String brightness;
  final String primary;
  final String? surface;
  final String? onSurface;
  final bool useMaterial3;
  final String? fontFamily;
  ThemeConfig(
      {required this.brightness,
      required this.primary,
      this.surface,
      this.onSurface,
      required this.useMaterial3,
      this.fontFamily});
  factory ThemeConfig.fromJson(Map<String, dynamic> json) =>
      _$ThemeConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class LayoutConfig {
  final String scaffold;
  final AppBarConfig appbar;
  @JsonKey(defaultValue: false)
  final bool visible;
  LayoutConfig(
      {required this.scaffold, required this.appbar, required this.visible});
  factory LayoutConfig.fromJson(Map<String, dynamic> json) =>
      _$LayoutConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class AppBarConfig {
  final bool visible;
  final List<AppBarAction> actions;
  AppBarConfig({required this.visible, required this.actions});
  factory AppBarConfig.fromJson(Map<String, dynamic> json) =>
      _$AppBarConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class AppBarAction {
  final String id;
  final String icon;
  final String action;
  AppBarAction({required this.id, required this.icon, required this.action});
  factory AppBarAction.fromJson(Map<String, dynamic> json) =>
      _$AppBarActionFromJson(json);
}

@JsonSerializable(createToJson: false)
class RouteConfig {
  final String path;
  final String kind;
  final String title;
  final String? url;
  @JsonKey(name: 'pull_to_refresh', defaultValue: false)
  final bool pullToRefresh;
  @JsonKey(name: 'appbar_visible', defaultValue: true)
  final bool appbarVisible;
  final String? icon;
  final String? label;

  RouteConfig({
    required this.path,
    required this.kind,
    required this.title,
    this.url,
    required this.pullToRefresh,
    required this.appbarVisible,
    this.icon,
    this.label,
  });
  factory RouteConfig.fromJson(Map<String, dynamic> json) =>
      _$RouteConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class NavigationConfig {
  final List<String> externalAllowlist;
  final DeepLinksConfig deepLinks;
  NavigationConfig({required this.externalAllowlist, required this.deepLinks});
  factory NavigationConfig.fromJson(Map<String, dynamic> json) =>
      _$NavigationConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class DeepLinksConfig {
  final bool enable;
  final List<String> hosts;
  DeepLinksConfig({required this.enable, required this.hosts});
  factory DeepLinksConfig.fromJson(Map<String, dynamic> json) =>
      _$DeepLinksConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class SecurityConfig {
  final List<String> restrictToHosts;
  SecurityConfig({required this.restrictToHosts});
  factory SecurityConfig.fromJson(Map<String, dynamic> json) =>
      _$SecurityConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class WebViewSettings {
  final bool javascriptEnabled;
  final bool domStorageEnabled;
  WebViewSettings(
      {required this.javascriptEnabled, required this.domStorageEnabled});
  factory WebViewSettings.fromJson(Map<String, dynamic> json) =>
      _$WebViewSettingsFromJson(json);
}

@JsonSerializable(createToJson: false)
class JsBridgeConfig {
  final bool enabled;
  final String name;
  final List<String> methods;
  final bool secureOriginOnly;
  final List<InboundEvent> inboundEvents;

  JsBridgeConfig({
    required this.enabled,
    required this.name,
    required this.methods,
    required this.secureOriginOnly,
    required this.inboundEvents,
  });

  factory JsBridgeConfig.fromJson(Map<String, dynamic> json) =>
      _$JsBridgeConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class InboundEvent {
  final String event;
  final List<String> args;
  final String action;

  InboundEvent({required this.event, required this.args, required this.action});

  factory InboundEvent.fromJson(Map<String, dynamic> json) =>
      _$InboundEventFromJson(json);
}

@JsonSerializable(createToJson: false)
class AdsConfig {
  final bool enabled;
  @JsonKey(name: 'consent_gate_with_ump')
  final bool consentGateWithUmp;
  final AdPlacements placements;

  AdsConfig({
    required this.enabled,
    required this.consentGateWithUmp,
    required this.placements,
  });

  factory AdsConfig.fromJson(Map<String, dynamic> json) =>
      _$AdsConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class AdPlacements {
  @JsonKey(name: 'global_banner')
  final AdPlacementConfig? globalBanner;

  @JsonKey(name: 'route_placements', fromJson: _placementsFromJson)
  final Map<String, AdPlacementConfig> routePlacements;

  AdPlacements({this.globalBanner, required this.routePlacements});

  factory AdPlacements.fromJson(Map<String, dynamic> json) =>
      _$AdPlacementsFromJson(json);

  static Map<String, AdPlacementConfig> _placementsFromJson(
      Map<String, dynamic> json) {
    return json.map((key, value) => MapEntry(
        key, AdPlacementConfig.fromJson(value as Map<String, dynamic>)));
  }
}

@JsonSerializable(createToJson: false)
class AdPlacementConfig {
  @JsonKey(name: 'screen_scope')
  final String screenScope;
  final String? route;
  final String format;
  final String position;
  @JsonKey(name: 'ad_unit_id')
  final String adUnitId;

  AdPlacementConfig({
    required this.screenScope,
    this.route,
    required this.format,
    required this.position,
    required this.adUnitId,
  });

  factory AdPlacementConfig.fromJson(Map<String, dynamic> json) =>
      _$AdPlacementConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class BehaviorOverridesConfig {
  @JsonKey(name: 'back_button')
  final BackButtonConfig backButton;

  BehaviorOverridesConfig({required this.backButton});

  factory BehaviorOverridesConfig.fromJson(Map<String, dynamic> json) =>
      _$BehaviorOverridesConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class BackButtonConfig {
  @JsonKey(name: 'confirm_before_exit')
  final bool confirmBeforeExit;

  BackButtonConfig({required this.confirmBeforeExit});

  factory BackButtonConfig.fromJson(Map<String, dynamic> json) =>
      _$BackButtonConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class UpdateConfig {
  @JsonKey(name: 'in_app_updates')
  final String inAppUpdates;

  UpdateConfig({required this.inAppUpdates});

  factory UpdateConfig.fromJson(Map<String, dynamic> json) =>
      _$UpdateConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class AnalyticsCrashConfig {
  final bool analytics;
  final bool crashlytics;

  AnalyticsCrashConfig({required this.analytics, required this.crashlytics});

  factory AnalyticsCrashConfig.fromJson(Map<String, dynamic> json) =>
      _$AnalyticsCrashConfigFromJson(json);
}

@JsonSerializable(createToJson: false)
class NotificationsConfig {
  @JsonKey(name: 'post_notifications_permission')
  final bool postNotificationsPermission;
  @JsonKey(name: 'fcm_enabled')
  final bool fcmEnabled;

  NotificationsConfig(
      {required this.postNotificationsPermission, required this.fcmEnabled});

  factory NotificationsConfig.fromJson(Map<String, dynamic> json) =>
      _$NotificationsConfigFromJson(json);
}
