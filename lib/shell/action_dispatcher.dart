import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';

/// Resolves config "action" strings into runnable callbacks.
///
/// Supported action grammars:
///   * `navigate:/some/path`       — `context.go(path)`
///   * `webview.reload`            — calls [onWebviewReload] if non-null
///   * `webview.back`              — calls [onWebviewBack] if non-null
///   * `bridge.<methodName>(...)`  — calls [onBridgeCall] if non-null
///   * `store.rate`                — opens Play Store review prompt
///   * `noop` / empty / null       — no-op
class ActionDispatcher {
  ActionDispatcher({
    this.onWebviewReload,
    this.onWebviewBack,
    this.onBridgeCall,
  });

  final VoidCallback? onWebviewReload;
  final VoidCallback? onWebviewBack;
  final void Function(String method, Map<String, dynamic> args)? onBridgeCall;

  Future<void> dispatch(BuildContext context, String? action) async {
    if (action == null || action.isEmpty || action == 'noop') return;

    if (action.startsWith('navigate:')) {
      final route = action.substring('navigate:'.length).trim();
      if (route.isNotEmpty && context.mounted) context.go(route);
      return;
    }

    if (action == 'webview.reload') {
      onWebviewReload?.call();
      return;
    }

    if (action == 'webview.back') {
      onWebviewBack?.call();
      return;
    }

    if (action.startsWith('bridge.')) {
      // bridge.scanBarcode(callback)  or  bridge.share(text)
      final body = action.substring('bridge.'.length);
      final paren = body.indexOf('(');
      final method = paren >= 0 ? body.substring(0, paren) : body;
      onBridgeCall?.call(method, const <String, dynamic>{});
      return;
    }

    if (action == 'store.rate') {
      try {
        final review = InAppReview.instance;
        if (await review.isAvailable()) {
          await review.requestReview();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('ActionDispatcher: in-app review unavailable: $e');
        }
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('ActionDispatcher: unknown action "$action"');
    }
  }
}
