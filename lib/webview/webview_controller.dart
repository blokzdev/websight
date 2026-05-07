import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:websight/bridge/js_bridge.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/system_chrome_controller.dart';
import 'package:websight/webview/popup_window.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Owns the platform [WebViewController] and the lifecycle around it for a
/// single route. Exposes high-level state (loading, error, current URL) to
/// the surrounding screen via [ChangeNotifier].
class WebsightWebViewController extends ChangeNotifier {
  WebsightWebViewController({
    required this.config,
    required this.features,
    required this.routeConfig,
    required this.context,
  }) {
    _initialize();
  }

  final WebSightConfig config;
  final WebSightFeatures features;
  final RouteConfig routeConfig;
  final BuildContext context;
  late final WebViewController controller;
  late final JsBridge _jsBridge;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  WebResourceError? _webError;
  WebResourceError? get webError => _webError;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _loadingProgress = 0;
  int get loadingProgress => _loadingProgress;

  bool _disposed = false;

  void _initialize() {
    controller = WebViewController()
      ..setJavaScriptMode(config.webviewSettings.javascriptEnabled
          ? JavaScriptMode.unrestricted
          : JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            _loadingProgress = p;
            notifyListeners();
          },
          onPageStarted: (_) {
            _webError = null;
            _isOffline = false;
            _isLoading = true;
            _loadingProgress = 0;
            notifyListeners();
          },
          onPageFinished: (url) {
            _isLoading = false;
            notifyListeners();
            unawaited(_injectUserScripts(url));
          },
          onWebResourceError: _onError,
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..setOnConsoleMessage((m) {
        if (kDebugMode) debugPrint('WebView console: ${m.message}');
      });

    _applyAndroidSpecifics();
    _applyUserAgent();

    if (config.jsBridge.enabled) {
      _jsBridge = JsBridge(
        controller: controller,
        config: config,
        features: features,
        context: context,
      );
      controller.addJavaScriptChannel(
        config.jsBridge.name,
        onMessageReceived: _jsBridge.handleMessage,
      );
    }
  }

  /// Track whether we're currently rendering an HTML5 fullscreen `<video>`
  /// custom view so [onHideCustomWidget] knows whether to restore the
  /// previous orientation / system-UI mode.
  Widget? _fullscreenWidget;
  bool _lockedOrientationForFullscreen = false;

  static const MethodChannel _platformChannel =
      MethodChannel('websight/method_channel');

  void _applyAndroidSpecifics() {
    if (controller.platform is! AndroidWebViewController) return;
    final android = controller.platform as AndroidWebViewController;
    AndroidWebViewController.enableDebugging(kDebugMode);
    android.setMediaPlaybackRequiresUserGesture(true);
    unawaited(android.setOnShowFileSelector(_onShowFileSelector));
    unawaited(
      android.setOnPlatformPermissionRequest(_onPlatformPermissionRequest),
    );
    unawaited(
      android.setGeolocationPermissionsPromptCallbacks(
        onShowPrompt: _onGeolocationPermissionsShowPrompt,
      ),
    );
    if (features.fullscreenVideo.enabled) {
      unawaited(
        android.setCustomWidgetCallbacks(
          onShowCustomWidget: _onShowFullscreenVideo,
          onHideCustomWidget: _onHideFullscreenVideo,
        ),
      );
    }
  }

  /// Routes WebChromeClient.onPermissionRequest (camera / mic) to the
  /// configured allowlist + the runtime permission_handler. The web
  /// permission grant is conditional on the OS-level permission also
  /// being granted; otherwise `getUserMedia` would resolve, then fail
  /// silently the moment the WebView tried to attach a real device.
  Future<void> _onPlatformPermissionRequest(
    PlatformWebViewPermissionRequest request,
  ) async {
    final allow = features.webviewPermissions;
    final wantedTypes = <WebViewPermissionResourceType>{};
    for (final type in request.types) {
      if (type == WebViewPermissionResourceType.camera && allow.allowCamera) {
        wantedTypes.add(type);
      } else if (type == WebViewPermissionResourceType.microphone &&
          allow.allowMicrophone) {
        wantedTypes.add(type);
      }
    }
    if (wantedTypes.length != request.types.length) {
      // At least one requested resource is denied by config; deny the
      // whole request to keep the WebView's resource set consistent.
      await request.deny();
      return;
    }
    // Request the matching OS-level permissions (no-op if already granted).
    final permissionsToRequest = <Permission>{};
    for (final type in wantedTypes) {
      if (type == WebViewPermissionResourceType.camera) {
        permissionsToRequest.add(Permission.camera);
      } else if (type == WebViewPermissionResourceType.microphone) {
        permissionsToRequest.add(Permission.microphone);
      }
    }
    final statuses = await permissionsToRequest.toList().request();
    final allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);
    if (allGranted) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  Future<GeolocationPermissionsResponse> _onGeolocationPermissionsShowPrompt(
    GeolocationPermissionsRequestParams params,
  ) async {
    final allow = features.webviewPermissions.allowGeolocation;
    if (!allow) {
      return const GeolocationPermissionsResponse(allow: false, retain: false);
    }
    // The wrapped page is asking for geolocation; require the runtime
    // location permission too.
    final status = await Permission.locationWhenInUse.request();
    final granted = status.isGranted || status.isLimited;
    return GeolocationPermissionsResponse(
      allow: granted,
      retain: granted && features.webviewPermissions.retainGeolocation,
    );
  }

  /// Hosts the `View` returned by `WebChromeClient.onShowCustomView` inside
  /// a Flutter overlay. The plugin already wraps it as a [Widget], so we
  /// just push it on top of the route.
  void _onShowFullscreenVideo(
    Widget widget,
    void Function() onHidden,
  ) {
    if (_fullscreenWidget != null) return;
    _fullscreenWidget = widget;

    if (features.fullscreenVideo.lockLandscape) {
      _lockedOrientationForFullscreen = true;
      unawaited(SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]));
    }
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 120),
        pageBuilder: (_, __, ___) => _FullscreenVideoHost(
          child: widget,
          onExit: () {
            onHidden();
            // The plugin will then call setCustomWidgetCallbacks.onHide,
            // which fires _onHideFullscreenVideo to restore state.
          },
        ),
      ),
    );
  }

  void _onHideFullscreenVideo() {
    if (_fullscreenWidget == null) return;
    _fullscreenWidget = null;
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
    // Restore platform default UI; the SystemChromeController re-applies
    // the configured edge-to-edge on the next route build.
    unawaited(SystemChromeController.resetToDefault());
    if (_lockedOrientationForFullscreen) {
      unawaited(
          SystemChrome.setPreferredOrientations(const <DeviceOrientation>[]));
      _lockedOrientationForFullscreen = false;
    }
  }

  /// Hook the Android WebView plugin invokes when the page surfaces a
  /// `<input type="file">`. We delegate the actual chooser to MainActivity's
  /// `pickFiles` method-channel handler, which launches the system file
  /// picker (and optionally camera capture), and returns the chosen URIs as
  /// strings the plugin hands back to the WebView.
  Future<List<String>> _onShowFileSelector(FileSelectorParams params) async {
    if (!features.fileUploads.enabled) return const <String>[];
    final allowMultiple = params.mode == FileSelectorMode.openMultiple;
    final acceptTypes =
        params.acceptTypes.where((t) => t.isNotEmpty).toList(growable: false);
    final mimeTypes =
        acceptTypes.isEmpty ? features.fileUploads.mimeTypes : acceptTypes;
    try {
      final result = await _platformChannel.invokeMethod<List<dynamic>>(
        'pickFiles',
        {
          'mimeTypes': mimeTypes,
          'allowMultiple': allowMultiple,
          'captureCamera': features.fileUploads.captureCamera,
        },
      );
      if (result == null) return const <String>[];
      return result.whereType<String>().toList(growable: false);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('pickFiles failed: ${e.code} ${e.message}');
      }
      return const <String>[];
    }
  }

  void _applyUserAgent() {
    final ua = features.userAgent;
    switch (ua.mode) {
      case 'custom':
        if ((ua.custom ?? '').isNotEmpty) {
          unawaited(controller.setUserAgent(ua.custom));
        }
        break;
      case 'append':
        if (ua.append.isNotEmpty) {
          // Read current UA and append our suffix; webview_flutter does not
          // expose getUserAgent synchronously, so we set it on the platform.
          unawaited(_appendUserAgent(ua.append));
        }
        break;
      case 'system':
      default:
        // leave default
        break;
    }
  }

  Future<void> _appendUserAgent(String suffix) async {
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      final current = await android.getUserAgent() ?? '';
      await controller
          .setUserAgent('${current.trim()} ${suffix.trim()}'.trim());
    }
  }

  Future<void> _injectUserScripts(String url) async {
    if (_disposed) return;
    final scripts = features.userScripts;
    if (scripts.injectCssAsset != null) {
      if (_disposed) return;
      await _injectCss(scripts.injectCssAsset!);
    }
    if (scripts.injectJsAsset != null) {
      if (_disposed) return;
      await _injectJs(scripts.injectJsAsset!);
    }
    // Safe-area CSS shim. Adds CSS variables that mirror Android's
    // window-inset insets, so a wrapped site can pad its own header /
    // footer with `padding-top: env(safe-area-inset-top)` style rules.
    // WebView already exposes `env(safe-area-inset-*)` natively, but
    // older Chrome versions need `viewport-fit=cover` injected too —
    // most blockchain explorers don't ship that.
    if (_disposed) return;
    if (features.systemUi.injectSafeAreaCss) {
      await _injectSafeAreaShim();
    }
    if (_disposed) return;
    if (config.jsBridge.enabled && _isBridgeAllowed(url)) {
      await _jsBridge.inject();
      if (_disposed) return;
      await _maybeInstallDownloadInterceptor();
      if (_disposed) return;
      if (features.multiWindow.enabled) {
        await _installPopupOpenInterceptor();
      }
    }
  }

  /// Inject `popupOpenInterceptorJs` so the page's `window.open()` calls are
  /// routed into our bridge → [PopupWindow] flow. Idempotent — the script
  /// guards itself against re-installation.
  Future<void> _installPopupOpenInterceptor() async {
    try {
      await controller.runJavaScript(
        popupOpenInterceptorJs(bridgeName: config.jsBridge.name),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Popup-open interceptor inject failed: $e');
    }
  }

  /// Make sure the WebView reports the right viewport for edge-to-edge
  /// layout. Without `viewport-fit=cover` Chrome will not fire
  /// `env(safe-area-inset-*)` — sites get a blank inset and overlap the
  /// transparent system bars.
  ///
  /// Two passes:
  ///   1. `:root` CSS variables (`--websight-safe-*`) so the wrapped site
  ///      can pad its own elements. Always on when `inject_safe_area_css`.
  ///   2. Optional `<body>` padding using `env(safe-area-inset-*)` for the
  ///      configured edges. This is the "just works" defense for sites
  ///      that don't natively respect insets — most of the public web,
  ///      including older blockchain explorers, news sites, etc.
  Future<void> _injectSafeAreaShim() async {
    final ui = features.systemUi;
    final padBody = ui.autoPadBody && ui.autoPadEdges.isNotEmpty;
    final padEdgesJson = jsonEncode(ui.autoPadEdges.toList()..sort());
    try {
      await controller.runJavaScript('''
(function () {
  if (window.__websightSafeAreaInjected) return;
  window.__websightSafeAreaInjected = true;
  try {
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta) {
      var content = meta.getAttribute('content') || '';
      if (!/viewport-fit\\s*=\\s*cover/i.test(content)) {
        meta.setAttribute(
          'content',
          (content ? content + ', ' : '') + 'viewport-fit=cover'
        );
      }
    } else {
      meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1, viewport-fit=cover';
      document.head.appendChild(meta);
    }
    var css = ':root { ' +
      '--websight-safe-top: env(safe-area-inset-top, 0px); ' +
      '--websight-safe-bottom: env(safe-area-inset-bottom, 0px); ' +
      '--websight-safe-left: env(safe-area-inset-left, 0px); ' +
      '--websight-safe-right: env(safe-area-inset-right, 0px); }';
    if ($padBody) {
      var edges = $padEdgesJson;
      var pad = function (e) {
        return edges.indexOf(e) >= 0
          ? 'env(safe-area-inset-' + e + ', 0px)'
          : '0px';
      };
      // @supports gate: skip on engines that don't grok env() at all so
      // we don't emit an invalid declaration. Box-sizing left at default
      // intentionally — overriding to border-box can shift sites that
      // already assume content-box body width.
      css += '@supports (padding: env(safe-area-inset-top)) {' +
        ' body {' +
        ' padding-top: ' + pad('top') + ';' +
        ' padding-bottom: ' + pad('bottom') + ';' +
        ' padding-left: ' + pad('left') + ';' +
        ' padding-right: ' + pad('right') + ';' +
        ' } }';
    }
    var style = document.createElement('style');
    style.setAttribute('data-websight-safearea', '1');
    style.appendChild(document.createTextNode(css));
    document.head.appendChild(style);
  } catch (e) {}
})();
''');
    } catch (e) {
      if (kDebugMode) debugPrint('Safe-area shim inject failed: $e');
    }
  }

  /// Wires a small JS click-listener that auto-routes downloadable links to
  /// the native handlers. We install once per page-finish (the helper itself
  /// is idempotent within a page). Gated by config so integrators who manage
  /// downloads themselves can opt out.
  Future<void> _maybeInstallDownloadInterceptor() async {
    if (!features.downloads.enabled || !features.downloads.useDownloadManager) {
      return;
    }
    final name = jsonEncode(config.jsBridge.name);
    try {
      await controller.runJavaScript(
        'if (window[$name] && typeof window[$name]._installDownloadInterceptor === "function") '
        '{ window[$name]._installDownloadInterceptor(); }',
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to install download interceptor: $e');
      }
    }
  }

  Future<void> _injectCss(String assetPath) async {
    try {
      final css = await rootBundle.loadString(assetPath);
      final encoded = jsonEncode(css);
      await controller.runJavaScript('''
(function () {
  var style = document.createElement('style');
  style.setAttribute('data-websight-injected', '1');
  style.appendChild(document.createTextNode($encoded));
  document.head.appendChild(style);
})();
''');
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to inject CSS $assetPath: $e');
    }
  }

  Future<void> _injectJs(String assetPath) async {
    try {
      final js = await rootBundle.loadString(assetPath);
      await controller.runJavaScript(js);
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to inject JS $assetPath: $e');
    }
  }

  bool _isBridgeAllowed(String url) {
    if (!config.jsBridge.secureOriginOnly) return true;
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return config.security.restrictToHosts.contains(uri.host);
  }

  void _onError(WebResourceError error) {
    _webError = error;
    _isLoading = false;
    // Treat connectivity-class errors as offline so the offline fallback
    // page renders rather than the generic error UI.
    final code = error.errorCode;
    final type = error.errorType?.name ?? '';
    _isOffline = type.contains('host') ||
        type.contains('connect') ||
        code == -2 /* ERROR_HOST_LOOKUP */ ||
        code == -6 /* ERROR_CONNECT */ ||
        code == -7 /* ERROR_TIMEOUT */;
    notifyListeners();
  }

  Future<NavigationDecision> _onNavigationRequest(
      NavigationRequest request) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.scheme == 'file' || uri.scheme == 'about') {
      debugPrint('Blocked insecure navigation to: ${uri.toString()}');
      return NavigationDecision.prevent;
    }

    final host = uri.host;
    if (config.security.restrictToHosts.contains(host)) {
      return NavigationDecision.navigate;
    }

    if (config.navigation.externalAllowlist.contains(host) ||
        const ['tel', 'mailto', 'geo', 'intent', 'market']
            .contains(uri.scheme)) {
      await _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    final currentUrl = await controller.currentUrl();
    final currentHost =
        currentUrl != null ? Uri.tryParse(currentUrl)?.host : null;
    if (currentHost != null && host.isNotEmpty && host != currentHost) {
      await _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    if (await canLaunchUrl(uri)) {
      await _launchExternal(uri);
      return NavigationDecision.prevent;
    }

    debugPrint('Blocked navigation to unhandled URL: ${uri.toString()}');
    return NavigationDecision.prevent;
  }

  Future<void> _launchExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> reload() {
    if (_disposed) return Future<void>.value();
    return controller.reload();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Wraps the platform-supplied custom widget (the View returned by
  /// `WebChromeClient.onShowCustomView`) in a black-backed Scaffold so it
  /// sits over the rest of the route. Tapping system back asks the WebView
  /// to exit fullscreen; the platform plugin then fires `onHideCustomWidget`
  /// which clears our overlay.
  Widget? get currentFullscreenWidget => _fullscreenWidget;

  /// Loads the bundled offline page as an HTML data URI. Avoids `file://` so
  /// strict mixed-content policy and our security delegate stay engaged.
  Future<void> loadOfflineFallback() async {
    try {
      final html = await rootBundle.loadString(features.offline.indexAsset);
      final dataUri = Uri.dataFromString(
        html,
        mimeType: 'text/html',
        encoding: const Utf8Codec(),
      );
      _webError = null;
      _isOffline = true;
      notifyListeners();
      await controller.loadRequest(dataUri);
    } catch (e) {
      if (kDebugMode) debugPrint('loadOfflineFallback failed: $e');
    }
  }
}

/// Black-backed scaffold that hosts the platform fullscreen-video widget.
/// System back asks the WebView (via [onExit]) to leave fullscreen; the
/// plugin then triggers `onHideCustomWidget` and clears the overlay.
class _FullscreenVideoHost extends StatelessWidget {
  const _FullscreenVideoHost({required this.child, required this.onExit});

  final Widget child;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        onExit();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: child,
      ),
    );
  }
}
