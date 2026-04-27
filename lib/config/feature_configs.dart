/// Lightweight, hand-rolled config classes for optional feature sections.
///
/// These coexist with `webview_config.dart` (json_serializable) but avoid the
/// build_runner regeneration burden every time we add a new feature. Each
/// controller calls the matching `fromMap` constructor against the raw decoded
/// YAML map exposed by `WebSightConfig.raw`.

import 'package:flutter/foundation.dart';

T? _typed<T>(Object? v) => v is T ? v : null;
bool _bool(Object? v, {bool fallback = false}) => v is bool ? v : fallback;
int _int(Object? v, {int fallback = 0}) =>
    v is int ? v : (v is num ? v.toInt() : fallback);
String _str(Object? v, {String fallback = ''}) => v is String ? v : fallback;
List<String> _strList(Object? v) => v is List
    ? v.whereType<String>().toList(growable: false)
    : const <String>[];

@immutable
class SplashFeature {
  final bool enabled;
  final int timeoutMs;
  final int fadeOutMs;
  final String? imageAsset;
  final String? backgroundColor;
  final String? tagline;

  const SplashFeature({
    required this.enabled,
    required this.timeoutMs,
    required this.fadeOutMs,
    required this.imageAsset,
    required this.backgroundColor,
    required this.tagline,
  });

  factory SplashFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const SplashFeature(
        enabled: false,
        timeoutMs: 1500,
        fadeOutMs: 300,
        imageAsset: null,
        backgroundColor: null,
        tagline: null,
      );
    }
    final raw = _typed<String>(map['image_asset']);
    return SplashFeature(
      enabled: _bool(map['enabled']),
      timeoutMs: _int(map['timeout_ms'], fallback: 1500),
      fadeOutMs: _int(map['fade_out_ms'], fallback: 300),
      imageAsset: (raw == null || raw.isEmpty)
          ? null
          : (raw.startsWith('assets/') ? raw : 'assets/$raw'),
      backgroundColor: _typed<String>(map['background_color']),
      tagline: _typed<String>(map['tagline']),
    );
  }
}

@immutable
class OfflineHtmlFeature {
  final bool fallbackWhenOffline;
  final String indexAsset;
  final bool openLocalByDefault;

  const OfflineHtmlFeature({
    required this.fallbackWhenOffline,
    required this.indexAsset,
    required this.openLocalByDefault,
  });

  factory OfflineHtmlFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const OfflineHtmlFeature(
        fallbackWhenOffline: false,
        indexAsset: 'assets/offline/index.html',
        openLocalByDefault: false,
      );
    }
    final raw = _str(map['index_asset'], fallback: 'assets/offline/index.html');
    // The YAML schema documents asset paths relative to the bundle root
    // (e.g. "offline/index.html"); accept both that and the absolute form.
    final asset = raw.startsWith('assets/') ? raw : 'assets/$raw';
    return OfflineHtmlFeature(
      fallbackWhenOffline: _bool(map['fallback_when_offline']),
      indexAsset: asset,
      openLocalByDefault: _bool(map['open_local_by_default']),
    );
  }
}

@immutable
class UserScripts {
  final String? injectCssAsset;
  final String? injectJsAsset;

  const UserScripts({this.injectCssAsset, this.injectJsAsset});

  factory UserScripts.fromMap(Map<String, dynamic>? webviewSettings) {
    final scripts = _typed<Map<String, dynamic>>(
        webviewSettings?['custom_user_scripts']);
    String? css;
    String? js;
    final cssMap = _typed<Map<String, dynamic>>(scripts?['inject_css']);
    if (cssMap != null && _bool(cssMap['enabled'])) {
      css = _normalizeAsset(_str(cssMap['asset_path']));
    }
    final jsMap = _typed<Map<String, dynamic>>(scripts?['inject_js']);
    if (jsMap != null && _bool(jsMap['enabled'])) {
      js = _normalizeAsset(_str(jsMap['asset_path']));
    }
    return UserScripts(injectCssAsset: css, injectJsAsset: js);
  }

  static String? _normalizeAsset(String raw) {
    if (raw.isEmpty) return null;
    return raw.startsWith('assets/') ? raw : 'assets/$raw';
  }
}

@immutable
class UserAgentMode {
  final String mode; // system | append | custom
  final String append;
  final String? custom;

  const UserAgentMode({required this.mode, required this.append, this.custom});

  factory UserAgentMode.fromMap(Map<String, dynamic>? appSection) {
    final ua = _typed<Map<String, dynamic>>(appSection?['user_agent']);
    return UserAgentMode(
      mode: _str(ua?['mode'], fallback: 'system'),
      append: _str(ua?['append']),
      custom: _typed<String>(ua?['custom']),
    );
  }
}

@immutable
class FileUploadsFeature {
  final bool enabled;
  final bool captureCamera;
  final List<String> mimeTypes;

  const FileUploadsFeature({
    required this.enabled,
    required this.captureCamera,
    required this.mimeTypes,
  });

  factory FileUploadsFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FileUploadsFeature(
        enabled: true,
        captureCamera: true,
        mimeTypes: <String>['*/*'],
      );
    }
    return FileUploadsFeature(
      enabled: _bool(map['enabled'], fallback: true),
      captureCamera: _bool(map['capture_camera'], fallback: true),
      mimeTypes: _strList(map['mime_types']).isEmpty
          ? const <String>['*/*']
          : _strList(map['mime_types']),
    );
  }
}

@immutable
class DownloadsFeature {
  final bool enabled;
  final bool useDownloadManager;
  final bool supportBlobUrls;

  const DownloadsFeature({
    required this.enabled,
    required this.useDownloadManager,
    required this.supportBlobUrls,
  });

  factory DownloadsFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const DownloadsFeature(
        enabled: true,
        useDownloadManager: true,
        supportBlobUrls: true,
      );
    }
    return DownloadsFeature(
      enabled: _bool(map['enabled'], fallback: true),
      useDownloadManager:
          _bool(map['use_android_download_manager'], fallback: true),
      supportBlobUrls: _bool(map['support_blob_urls'], fallback: true),
    );
  }
}

@immutable
class BillingFeature {
  final bool enabled;
  final List<String> productIds;

  const BillingFeature({required this.enabled, required this.productIds});

  factory BillingFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const BillingFeature(enabled: false, productIds: <String>[]);
    }
    return BillingFeature(
      enabled: _bool(map['inapp_enabled']),
      productIds: _strList(map['product_ids']),
    );
  }
}

@immutable
class RatingPromptFeature {
  final bool enabled;
  final int afterLaunches;

  const RatingPromptFeature({
    required this.enabled,
    required this.afterLaunches,
  });

  factory RatingPromptFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const RatingPromptFeature(enabled: false, afterLaunches: 5);
    }
    return RatingPromptFeature(
      enabled: _bool(map['enabled']),
      afterLaunches: _int(map['after_launches'], fallback: 5),
    );
  }
}

@immutable
class FabFeature {
  final bool visible;
  final String icon;
  final String? action;

  const FabFeature({required this.visible, required this.icon, this.action});

  factory FabFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FabFeature(visible: false, icon: 'Icons.add');
    }
    return FabFeature(
      visible: _bool(map['visible']),
      icon: _str(map['icon'], fallback: 'Icons.add'),
      action: _typed<String>(map['action']),
    );
  }
}

@immutable
class TabItem {
  final String label;
  final String icon;
  final String route;

  const TabItem({
    required this.label,
    required this.icon,
    required this.route,
  });

  factory TabItem.fromMap(Map<String, dynamic> map) {
    return TabItem(
      label: _str(map['label']),
      icon: _str(map['icon']),
      route: _str(map['route']),
    );
  }
}

@immutable
class BottomTabsFeature {
  final bool visible;
  final int initialIndex;
  final List<TabItem> items;

  const BottomTabsFeature({
    required this.visible,
    required this.initialIndex,
    required this.items,
  });

  factory BottomTabsFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const BottomTabsFeature(
        visible: false,
        initialIndex: 0,
        items: <TabItem>[],
      );
    }
    final rawItems = map['items'];
    final items = (rawItems is List)
        ? rawItems
            .whereType<Map>()
            .map((e) => TabItem.fromMap(Map<String, dynamic>.from(e)))
            .where((t) => t.route.isNotEmpty)
            .toList(growable: false)
        : const <TabItem>[];
    return BottomTabsFeature(
      visible: _bool(map['visible']),
      initialIndex: _int(map['initial_index']),
      items: items,
    );
  }
}

@immutable
class DrawerItem {
  final String title;
  final String icon;
  final String? route;
  final String? action;

  const DrawerItem({
    required this.title,
    required this.icon,
    this.route,
    this.action,
  });

  factory DrawerItem.fromMap(Map<String, dynamic> map) {
    return DrawerItem(
      title: _str(map['title']),
      icon: _str(map['icon']),
      route: _typed<String>(map['route']),
      action: _typed<String>(map['action']),
    );
  }
}

@immutable
class DrawerFeature {
  final bool visible;
  final String headerTitle;
  final String? headerSubtitle;
  final String? avatarAsset;
  final List<DrawerItem> items;
  final List<DrawerItem> footerItems;

  const DrawerFeature({
    required this.visible,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.avatarAsset,
    required this.items,
    required this.footerItems,
  });

  factory DrawerFeature.fromMap(Map<String, dynamic>? map, String appName) {
    if (map == null) {
      return DrawerFeature(
        visible: false,
        headerTitle: appName,
        headerSubtitle: null,
        avatarAsset: null,
        items: const <DrawerItem>[],
        footerItems: const <DrawerItem>[],
      );
    }
    final header = _typed<Map<String, dynamic>>(map['header']);
    return DrawerFeature(
      visible: _bool(map['visible'], fallback: true),
      headerTitle: _str(header?['title'], fallback: appName),
      headerSubtitle: _typed<String>(header?['subtitle']),
      avatarAsset: _typed<String>(header?['avatar_asset']),
      items: _items(map['items']),
      footerItems: _items(map['footer_items']),
    );
  }

  static List<DrawerItem> _items(Object? raw) {
    if (raw is! List) return const <DrawerItem>[];
    return raw
        .whereType<Map>()
        .map((m) => DrawerItem.fromMap(Map<String, dynamic>.from(m)))
        .where((i) => i.title.isNotEmpty)
        .toList(growable: false);
  }
}

@immutable
class ErrorPagesFeature {
  final bool showOfflinePage;
  final bool retryButton;

  const ErrorPagesFeature({
    required this.showOfflinePage,
    required this.retryButton,
  });

  factory ErrorPagesFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ErrorPagesFeature(
          showOfflinePage: true, retryButton: true);
    }
    return ErrorPagesFeature(
      showOfflinePage: _bool(map['show_offline_page'], fallback: true),
      retryButton: _bool(map['retry_button'], fallback: true),
    );
  }
}

@immutable
class WebSightFeatures {
  final SplashFeature splash;
  final OfflineHtmlFeature offline;
  final UserScripts userScripts;
  final UserAgentMode userAgent;
  final FileUploadsFeature fileUploads;
  final DownloadsFeature downloads;
  final BillingFeature billing;
  final RatingPromptFeature rating;
  final FabFeature fab;
  final BottomTabsFeature bottomTabs;
  final DrawerFeature drawer;
  final ErrorPagesFeature errorPages;

  const WebSightFeatures({
    required this.splash,
    required this.offline,
    required this.userScripts,
    required this.userAgent,
    required this.fileUploads,
    required this.downloads,
    required this.billing,
    required this.rating,
    required this.fab,
    required this.bottomTabs,
    required this.drawer,
    required this.errorPages,
  });

  factory WebSightFeatures.fromRaw(
    Map<String, dynamic> raw, {
    required String appName,
  }) {
    final webviewSettings =
        _typed<Map<String, dynamic>>(raw['webview_settings']);
    final flutterUi = _typed<Map<String, dynamic>>(raw['flutter_ui']);
    final layout = _typed<Map<String, dynamic>>(flutterUi?['layout']);
    final behaviorOverrides =
        _typed<Map<String, dynamic>>(raw['behavior_overrides']);
    return WebSightFeatures(
      splash: SplashFeature.fromMap(_typed<Map<String, dynamic>>(raw['splash'])),
      offline: OfflineHtmlFeature.fromMap(
          _typed<Map<String, dynamic>>(raw['offline_local_html'])),
      userScripts: UserScripts.fromMap(webviewSettings),
      userAgent:
          UserAgentMode.fromMap(_typed<Map<String, dynamic>>(raw['app'])),
      fileUploads: FileUploadsFeature.fromMap(
          _typed<Map<String, dynamic>>(raw['file_uploads'])),
      downloads: DownloadsFeature.fromMap(
          _typed<Map<String, dynamic>>(raw['downloads'])),
      billing:
          BillingFeature.fromMap(_typed<Map<String, dynamic>>(raw['billing'])),
      rating: RatingPromptFeature.fromMap(
          _typed<Map<String, dynamic>>(raw['rating_prompt'])),
      fab: FabFeature.fromMap(
          _typed<Map<String, dynamic>>(layout?['floating_action_button'])),
      bottomTabs: BottomTabsFeature.fromMap(
          _typed<Map<String, dynamic>>(layout?['bottom_tabs'])),
      drawer: DrawerFeature.fromMap(
        _typed<Map<String, dynamic>>(layout?['drawer']),
        appName,
      ),
      errorPages: ErrorPagesFeature.fromMap(
          _typed<Map<String, dynamic>>(behaviorOverrides?['error_pages'])),
    );
  }
}
