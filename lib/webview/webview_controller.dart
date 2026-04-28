import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import 'package:websight/bridge/js_bridge.dart';
import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';

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
      _jsBridge =
          JsBridge(controller: controller, config: config, context: context);
      controller.addJavaScriptChannel(
        config.jsBridge.name,
        onMessageReceived: _jsBridge.handleMessage,
      );
    }
  }

  static const MethodChannel _platformChannel =
      MethodChannel('websight/method_channel');

  void _applyAndroidSpecifics() {
    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      AndroidWebViewController.enableDebugging(kDebugMode);
      android.setMediaPlaybackRequiresUserGesture(true);
      unawaited(android.setOnShowFileSelector(_onShowFileSelector));
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
    if (_disposed) return;
    if (config.jsBridge.enabled && _isBridgeAllowed(url)) {
      await _jsBridge.inject();
      if (_disposed) return;
      await _maybeInstallDownloadInterceptor();
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
