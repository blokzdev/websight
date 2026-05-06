/// Lightweight, hand-rolled config classes for optional feature sections.
///
/// These coexist with `webview_config.dart` (json_serializable) but avoid the
/// build_runner regeneration burden every time we add a new feature. Each
/// controller calls the matching `fromMap` constructor against the raw decoded
/// YAML map exposed by `WebSightConfig.raw`.
library;

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
    final scripts =
        _typed<Map<String, dynamic>>(webviewSettings?['custom_user_scripts']);
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
            .whereType<Map<dynamic, dynamic>>()
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
        .whereType<Map<dynamic, dynamic>>()
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
      return const ErrorPagesFeature(showOfflinePage: true, retryButton: true);
    }
    return ErrorPagesFeature(
      showOfflinePage: _bool(map['show_offline_page'], fallback: true),
      retryButton: _bool(map['retry_button'], fallback: true),
    );
  }
}

@immutable
class UnofficialDisclaimerFeature {
  final bool enabled;
  final String title;
  final String body;
  final String acceptLabel;
  final String declineLabel;
  final bool requireAccept;

  const UnofficialDisclaimerFeature({
    required this.enabled,
    required this.title,
    required this.body,
    required this.acceptLabel,
    required this.declineLabel,
    required this.requireAccept,
  });

  /// A stable identifier derived from the body text. Acceptance is keyed on
  /// this digest so any edit to the disclaimer text invalidates prior
  /// acceptances and re-prompts users on next launch — no manual version
  /// bumping required.
  String get bodyDigest =>
      'd${body.trim().hashCode.toUnsigned(32).toRadixString(16)}';

  factory UnofficialDisclaimerFeature.fromMap(Map<String, dynamic>? map) {
    const defaults = UnofficialDisclaimerFeature(
      enabled: false,
      title: 'Unofficial app',
      body: 'This app is an unofficial WebView wrapper. It is not affiliated '
          'with or endorsed by the operator of the embedded website. '
          'Content is provided as-is by that website; the publisher of this '
          'app is not responsible for its accuracy or availability.\n\n'
          'By tapping "I understand", you accept these terms and use the '
          'app for personal, development, or educational purposes.',
      acceptLabel: 'I understand',
      declineLabel: 'Exit',
      requireAccept: true,
    );
    if (map == null) return defaults;
    return UnofficialDisclaimerFeature(
      enabled: _bool(map['enabled']),
      title: _str(map['title'], fallback: defaults.title),
      body: _str(map['body'], fallback: defaults.body),
      acceptLabel: _str(map['accept_label'], fallback: defaults.acceptLabel),
      declineLabel: _str(map['decline_label'], fallback: defaults.declineLabel),
      requireAccept: _bool(map['require_accept'], fallback: true),
    );
  }
}

@immutable
class LegalFeature {
  final UnofficialDisclaimerFeature unofficialDisclaimer;

  const LegalFeature({required this.unofficialDisclaimer});

  factory LegalFeature.fromMap(Map<String, dynamic>? map) {
    return LegalFeature(
      unofficialDisclaimer: UnofficialDisclaimerFeature.fromMap(
        _typed<Map<String, dynamic>>(map?['unofficial_disclaimer']),
      ),
    );
  }
}

/// How the system status / navigation bars are configured. Controls
/// `SystemChrome.setEnabledSystemUIMode` + `setSystemUIOverlayStyle`.
///
/// `mode`:
///   - `default`           — Flutter's default (system bars opaque, layout
///                           insets respected). Use when the wrapped site
///                           expects browser-like chrome.
///   - `edge_to_edge`      — Window draws under transparent system bars; the
///                           default for WebSight v1.1+. Pairs with
///                           `extendBodyBehindAppBar` in the shell.
///   - `immersive_sticky`  — System bars hidden until the user swipes; bars
///                           overlay rather than push content. Good for
///                           media-heavy sites.
///   - `leanback`          — Bars hidden, no swipe-to-reveal (TV / kiosk).
///
/// Per-bar `icon_brightness` of `auto` derives from the active theme: a
/// `dark` theme yields `light` icons (so they're visible on dark surfaces)
/// and vice versa.
@immutable
class SystemUiBar {
  final bool visible;
  final bool transparent;
  final String iconBrightness; // auto | light | dark

  const SystemUiBar({
    required this.visible,
    required this.transparent,
    required this.iconBrightness,
  });

  factory SystemUiBar.fromMap(
    Map<String, dynamic>? map, {
    required bool defaultTransparent,
  }) {
    if (map == null) {
      return SystemUiBar(
        visible: true,
        transparent: defaultTransparent,
        iconBrightness: 'auto',
      );
    }
    return SystemUiBar(
      visible: _bool(map['visible'], fallback: true),
      transparent: _bool(map['transparent'], fallback: defaultTransparent),
      iconBrightness: _str(map['icon_brightness'], fallback: 'auto'),
    );
  }
}

@immutable
class SystemUiFeature {
  final String mode; // default | edge_to_edge | immersive_sticky | leanback
  final SystemUiBar statusBar;
  final SystemUiBar navigationBar;
  final bool injectSafeAreaCss;

  /// When `true` (default), the safe-area shim also adds
  /// `padding: env(safe-area-inset-*)` to `<body>` so wrapped sites that
  /// don't natively account for safe-area insets don't get their content
  /// (logos, sticky headers) sliding under the transparent system bars.
  ///
  /// Sites that DO handle insets themselves should disable this
  /// (`auto_pad_body: false`) to avoid double-padding. Sites with elaborate
  /// `position: fixed` headers may still need a custom CSS injection — body
  /// padding only addresses content in normal flow.
  final bool autoPadBody;

  /// Which edges of `<body>` get safe-area padding when [autoPadBody] is on.
  /// Members are any of: `top`, `bottom`, `left`, `right`. The defaults
  /// (`top`, `bottom`) cover the status bar and gesture / nav bar — the
  /// only edges that overlap content in the common portrait orientation.
  /// `left` / `right` matter only on landscape with side-notched displays.
  final Set<String> autoPadEdges;

  const SystemUiFeature({
    required this.mode,
    required this.statusBar,
    required this.navigationBar,
    required this.injectSafeAreaCss,
    required this.autoPadBody,
    required this.autoPadEdges,
  });

  bool get isEdgeToEdge => mode == 'edge_to_edge';
  bool get isImmersive => mode == 'immersive_sticky' || mode == 'leanback';

  static const Set<String> _defaultPadEdges = <String>{'top', 'bottom'};
  static const Set<String> _validPadEdges = <String>{
    'top',
    'bottom',
    'left',
    'right',
  };

  factory SystemUiFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SystemUiFeature(
        mode: 'edge_to_edge',
        statusBar: SystemUiBar.fromMap(null, defaultTransparent: true),
        navigationBar: SystemUiBar.fromMap(null, defaultTransparent: true),
        injectSafeAreaCss: true,
        autoPadBody: true,
        autoPadEdges: _defaultPadEdges,
      );
    }
    final mode = _str(map['mode'], fallback: 'edge_to_edge');
    final transparentDefault = mode != 'default';
    return SystemUiFeature(
      mode: mode,
      statusBar: SystemUiBar.fromMap(
        _typed<Map<String, dynamic>>(map['status_bar']),
        defaultTransparent: transparentDefault,
      ),
      navigationBar: SystemUiBar.fromMap(
        _typed<Map<String, dynamic>>(map['navigation_bar']),
        defaultTransparent: transparentDefault,
      ),
      injectSafeAreaCss: _bool(map['inject_safe_area_css'], fallback: true),
      autoPadBody: _bool(map['auto_pad_body'], fallback: true),
      autoPadEdges: _padEdges(map['auto_pad_edges']),
    );
  }

  /// Filters a YAML list down to known edge names. Unknown values are
  /// dropped silently (debug log lives in the controller).
  static Set<String> _padEdges(Object? raw) {
    if (raw == null) return _defaultPadEdges;
    final list = _strList(raw);
    if (list.isEmpty) return const <String>{};
    final filtered = list
        .map((e) => e.toLowerCase())
        .where(_validPadEdges.contains)
        .toSet();
    return filtered;
  }
}

/// Multi-window popup config. Most sites that "open in a new tab" for OAuth
/// (Google / Microsoft / Twitter / Facebook sign-in dialogs) call
/// `window.open(url)`. webview_flutter_android does not expose a public
/// `onCreateWindow` API, so we intercept `window.open` from injected JS and
/// route the URL into a Flutter-side popup `WebView` route.
@immutable
class MultiWindowFeature {
  final bool enabled;
  final bool closeOnParentHost;
  final bool reloadParentOnClose;

  const MultiWindowFeature({
    required this.enabled,
    required this.closeOnParentHost,
    required this.reloadParentOnClose,
  });

  factory MultiWindowFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const MultiWindowFeature(
        enabled: true,
        closeOnParentHost: true,
        reloadParentOnClose: true,
      );
    }
    return MultiWindowFeature(
      enabled: _bool(map['enabled'], fallback: true),
      closeOnParentHost: _bool(map['close_on_parent_host'], fallback: true),
      reloadParentOnClose:
          _bool(map['reload_parent_on_close'], fallback: true),
    );
  }
}

@immutable
class FullscreenVideoFeature {
  final bool enabled;
  final bool lockLandscape;

  const FullscreenVideoFeature({
    required this.enabled,
    required this.lockLandscape,
  });

  factory FullscreenVideoFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const FullscreenVideoFeature(
        enabled: true,
        lockLandscape: false,
      );
    }
    return FullscreenVideoFeature(
      enabled: _bool(map['enabled'], fallback: true),
      lockLandscape: _bool(map['lock_landscape']),
    );
  }
}

/// Allowlist for `WebChromeClient.onPermissionRequest` calls (HTML5
/// `getUserMedia`, EME, geolocation prompts triggered by `navigator.*`).
/// Default-deny would break in-page QR scanners / camera demos / mic input,
/// so for a wrapper meant to forward an existing site, sensible defaults
/// allow camera + mic + geo and gate `protected_media`.
@immutable
class WebViewPermissionsFeature {
  final bool allowCamera;
  final bool allowMicrophone;
  final bool allowGeolocation;
  final bool allowProtectedMedia;
  final bool retainGeolocation;

  const WebViewPermissionsFeature({
    required this.allowCamera,
    required this.allowMicrophone,
    required this.allowGeolocation,
    required this.allowProtectedMedia,
    required this.retainGeolocation,
  });

  factory WebViewPermissionsFeature.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const WebViewPermissionsFeature(
        allowCamera: true,
        allowMicrophone: true,
        allowGeolocation: true,
        allowProtectedMedia: false,
        retainGeolocation: false,
      );
    }
    return WebViewPermissionsFeature(
      allowCamera: _bool(map['allow_camera'], fallback: true),
      allowMicrophone: _bool(map['allow_microphone'], fallback: true),
      allowGeolocation: _bool(map['allow_geolocation'], fallback: true),
      allowProtectedMedia: _bool(map['allow_protected_media']),
      retainGeolocation: _bool(map['retain_geolocation']),
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
  final LegalFeature legal;
  final SystemUiFeature systemUi;
  final MultiWindowFeature multiWindow;
  final FullscreenVideoFeature fullscreenVideo;
  final WebViewPermissionsFeature webviewPermissions;

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
    required this.legal,
    required this.systemUi,
    required this.multiWindow,
    required this.fullscreenVideo,
    required this.webviewPermissions,
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
    final permissions = _typed<Map<String, dynamic>>(raw['permissions']);
    return WebSightFeatures(
      splash:
          SplashFeature.fromMap(_typed<Map<String, dynamic>>(raw['splash'])),
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
      legal: LegalFeature.fromMap(_typed<Map<String, dynamic>>(raw['legal'])),
      systemUi: SystemUiFeature.fromMap(
          _typed<Map<String, dynamic>>(flutterUi?['system_ui'])),
      multiWindow: MultiWindowFeature.fromMap(
          _typed<Map<String, dynamic>>(webviewSettings?['multi_window'])),
      fullscreenVideo: FullscreenVideoFeature.fromMap(
          _typed<Map<String, dynamic>>(webviewSettings?['fullscreen_video'])),
      webviewPermissions: WebViewPermissionsFeature.fromMap(
          _typed<Map<String, dynamic>>(permissions?['webview'])),
    );
  }
}
