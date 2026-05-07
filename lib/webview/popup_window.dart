import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A modal WebView screen for handling popups opened by the wrapped site,
/// most commonly OAuth dialogs (Google / Microsoft / Twitter / Facebook
/// "Sign in with…" flows that call `window.open(authorizeUrl)` and then
/// either redirect back to a same-host callback or call `window.close()`).
///
/// `webview_flutter_android` 4.x does not expose a public `onCreateWindow`
/// callback, so we don't try to bridge the platform's native multi-window
/// flow. Instead the parent WebView gets a small JS shim that overrides
/// `window.open()` to forward the URL to our JS bridge, which pushes a
/// [PopupWindow] route. This handles 95% of OAuth flows without touching
/// the platform plugin.
class PopupWindow extends StatefulWidget {
  const PopupWindow({
    super.key,
    required this.initialUrl,
    required this.parentHosts,
    required this.allowedHosts,
    required this.closeOnParentHost,
    required this.onClosed,
    this.title,
  });

  /// The URL passed to `window.open`. Must be a full http(s) URL.
  final String initialUrl;

  /// Hosts considered "the parent site". When the popup navigates to one of
  /// these (e.g. an OAuth callback URL) we close it automatically.
  final Set<String> parentHosts;

  /// Hosts the popup is allowed to navigate to. Typically the parent hosts
  /// plus the OAuth provider's domain. If a host outside this set is hit,
  /// we hand off to the platform browser instead of loading in the popup.
  final Set<String> allowedHosts;

  /// When `true` (the default), navigation back to a host in [parentHosts]
  /// closes the popup and notifies the parent via [onClosed]. Some flows
  /// (e.g. SAML) want to stay in the popup until `window.close()` fires —
  /// disable this knob in that case.
  final bool closeOnParentHost;

  /// Callback fired when the popup is dismissed for any reason (auto-close
  /// after parent-host return, `window.close()`, or user back-press). The
  /// parent WebView typically reloads on this signal.
  final VoidCallback onClosed;

  final String? title;

  @override
  State<PopupWindow> createState() => _PopupWindowState();

  /// Push this route on top of the current Navigator, returning when the
  /// popup is dismissed.
  static Future<void> push(
    BuildContext context, {
    required String initialUrl,
    required Set<String> parentHosts,
    required Set<String> allowedHosts,
    bool closeOnParentHost = true,
    String? title,
    VoidCallback? onClosed,
  }) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PopupWindow(
          initialUrl: initialUrl,
          parentHosts: parentHosts,
          allowedHosts: allowedHosts,
          closeOnParentHost: closeOnParentHost,
          onClosed: onClosed ?? () {},
          title: title,
        ),
      ),
    );
  }
}

class _PopupWindowState extends State<PopupWindow> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _closed = false;
  String _displayHost = '';

  @override
  void initState() {
    super.initState();
    _displayHost = Uri.tryParse(widget.initialUrl)?.host ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _displayHost = Uri.tryParse(url)?.host ?? _displayHost;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            unawaited(_installCloseSentinel());
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      );
    _controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<NavigationDecision> _onNavigationRequest(
    NavigationRequest request,
  ) async {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    if (uri.scheme == 'about' || uri.scheme == 'file') {
      return NavigationDecision.prevent;
    }

    final host = uri.host;
    if (widget.closeOnParentHost && widget.parentHosts.contains(host)) {
      _dismiss();
      return NavigationDecision.prevent;
    }

    if (widget.allowedHosts.contains(host) ||
        widget.parentHosts.contains(host)) {
      return NavigationDecision.navigate;
    }

    // Unknown host — kick to the system browser. OAuth providers redirect
    // back to the parent (handled above), so anything else is genuinely
    // outbound.
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return NavigationDecision.prevent;
  }

  /// Watches for `window.close()` from inside the popup. Many OAuth
  /// providers call it after writing a postMessage to the opener; we treat
  /// either a `<title>websight-popup-closed</title>` marker or a
  /// `__websightPopupClosed` flag on `window` as the signal.
  Future<void> _installCloseSentinel() async {
    try {
      await _controller.runJavaScript('''
(function () {
  if (window.__websightPopupSentinelInstalled) return;
  window.__websightPopupSentinelInstalled = true;
  var origClose = window.close;
  window.close = function () {
    try { document.title = 'websight-popup-closed'; } catch (e) {}
    window.__websightPopupClosed = true;
    try { return origClose.apply(window, arguments); } catch (e) {}
  };
})();
''');
    } catch (_) {
      // best-effort; older WebView versions may reject the override
    }
  }

  void _dismiss() {
    if (_closed) return;
    _closed = true;
    widget.onClosed();
    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title ?? (_displayHost.isNotEmpty ? _displayHost : 'Sign in');
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canBack = await _controller.canGoBack();
        if (canBack) {
          await _controller.goBack();
          return;
        }
        _dismiss();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16),
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: _dismiss,
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}

/// JS injected into the parent WebView to convert `window.open(url)` calls
/// into bridge messages. We post via the native channel so the host-side
/// dispatcher can pop a [PopupWindow] route. Calls without a URL (just
/// `window.open()` with no args) are left to the platform — that's the
/// blank-tab pattern, not OAuth.
String popupOpenInterceptorJs({required String bridgeName}) {
  return '''
(function () {
  if (window.__websightOpenIntercepted) return;
  window.__websightOpenIntercepted = true;
  var bridge = window["$bridgeName"];
  if (!bridge || typeof bridge.postMessage !== "function") return;
  var origOpen = window.open;
  window.open = function (url, target, features) {
    try {
      if (url && typeof url === "string") {
        bridge.postMessage(JSON.stringify({
          method: "openPopup",
          params: { url: String(url) }
        }));
        return null;
      }
    } catch (e) {}
    try { return origOpen.apply(window, arguments); } catch (e) { return null; }
  };
})();
''';
}
