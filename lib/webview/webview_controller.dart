import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/bridge/js_bridge.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class WebsightWebViewController extends ChangeNotifier {
  final WebSightConfig config;
  final RouteConfig routeConfig;
  late final WebViewController controller;
  late final JsBridge _jsBridge;
  final BuildContext context;

  WebResourceError? _webError;
  WebResourceError? get webError => _webError;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  int _loadingProgress = 0;
  int get loadingProgress => _loadingProgress;

  WebsightWebViewController(
      {required this.config,
      required this.routeConfig,
      required this.context}) {
    _initialize();
  }

  void _initialize() {
    controller = WebViewController()
      ..setJavaScriptMode(config.webviewSettings.javascriptEnabled
          ? JavaScriptMode.unrestricted
          : JavaScriptMode.disabled)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            _loadingProgress = progress;
            notifyListeners();
          },
          onPageStarted: (String url) {
            _webError = null;
            _isLoading = true;
            _loadingProgress = 0;
            notifyListeners();
          },
          onPageFinished: (String url) {
            _isLoading = false;
            notifyListeners();
            _injectDependencies(url);
          },
          onWebResourceError: (WebResourceError error) {
            // TODO: `isForMainFrame` is not available on all platforms.
            // if (error.isForMainFrame ?? false) {
            //   _webError = error;
            //   _isLoading = false;
            //   notifyListeners();
            // }
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..setOnConsoleMessage((message) {
        if (kDebugMode) {
          print('WebView Console: ${message.message}');
        }
      });

    if (config.jsBridge.enabled) {
      _jsBridge =
          JsBridge(controller: controller, config: config, context: context);
      controller.addJavaScriptChannel(
        config.jsBridge.name,
        onMessageReceived: _jsBridge.handleMessage,
      );
    }
  }

  void _injectDependencies(String url) {
    if (config.jsBridge.enabled && _isBridgeAllowed(url)) {
      _jsBridge.inject();
    }
  }

  bool _isBridgeAllowed(String url) {
    if (!config.jsBridge.secureOriginOnly) {
      return true;
    }
    final uri = Uri.parse(url);
    return config.security.restrictToHosts.contains(uri.host);
  }

  /// Reloads the current WebView page and returns a Future that completes when the reload is done.
  Future<void> reload() {
    return controller.reload();
  }

  Future<NavigationDecision> _handleNavigationRequest(
      NavigationRequest request) async {
    final Uri uri = Uri.parse(request.url);
    final String host = uri.host;

    if (uri.scheme == 'file' || uri.scheme == 'about') {
      debugPrint('Blocked insecure navigation to: ${uri.toString()}');
      return NavigationDecision.prevent;
    }

    if (config.security.restrictToHosts.contains(host)) {
      return NavigationDecision.navigate;
    }

    if (config.navigation.externalAllowlist.contains(host)) {
      _launchExternalUrl(uri);
      return NavigationDecision.prevent;
    }

    // A simple heuristic to treat all cross-origin navigations as pop-ups.
    final currentHost = await controller.currentUrl().then((url) => url != null ? Uri.parse(url).host : null);
    if (currentHost != null && host != currentHost) {
        _launchExternalUrl(uri);
        return NavigationDecision.prevent;
    }

    if (await canLaunchUrl(uri)) {
      _launchExternalUrl(uri);
      return NavigationDecision.prevent;
    }

    debugPrint('Blocked navigation to unhandled URL: ${uri.toString()}');
    return NavigationDecision.prevent;
  }

  Future<void> _launchExternalUrl(Uri url) async {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (kDebugMode) {
        print('Could not launch $url');
      }
    }
  }
}
