import 'dart:convert';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:websight/config/webview_config.dart';

/// Stable error codes returned to the JS bridge layer. Mirrors the codes used
/// on the Kotlin side (see `MainActivity.kt`).
class BridgeErrorCodes {
  static const String permission = 'E_PERMISSION';
  static const String canceled = 'E_CANCELED';
  static const String args = 'E_ARGS';
  static const String internal = 'E_INTERNAL';
  static const String origin = 'E_ORIGIN';
  static const String unsupported = 'E_UNSUPPORTED';
}

/// Bridges JavaScript invocations from the WebView into native operations.
///
/// Security model:
///   * Method dispatch is gated by [JsBridgeConfig.methods]. Methods not in
///     the allowlist are dropped.
///   * If [JsBridgeConfig.secureOriginOnly] is true, calls are dropped unless
///     the WebView's current origin is in [SecurityConfig.restrictToHosts].
///     This is also enforced at injection time (see `webview_controller.dart`),
///     but runtime checks defend against navigation races.
class JsBridge {
  JsBridge({
    required this.controller,
    required this.config,
    required this.context,
  });

  final WebViewController controller;
  final WebSightConfig config;
  final BuildContext context;

  static const MethodChannel _platform = MethodChannel('websight/method_channel');

  /// Injects the helper script and instantiates the bridge object on `window`.
  Future<void> inject() async {
    final js = await rootBundle.loadString('assets/websight.js');
    await controller.runJavaScript(js);
    final name = config.jsBridge.name;
    final encoded = jsonEncode(name);
    await controller.runJavaScript(
      'window[$encoded] = new WebSightBridgeInternal($encoded);',
    );
  }

  /// Entry point for messages posted via `window.<bridgeName>.postMessage`.
  Future<void> handleMessage(JavaScriptMessage message) async {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(message.message);
      if (parsed is! Map) {
        debugPrint('JsBridge: ignored non-map message: ${message.message}');
        return;
      }
      decoded = Map<String, dynamic>.from(parsed);
    } catch (e) {
      debugPrint('JsBridge: invalid JSON: $e');
      return;
    }

    final method = decoded['method'];
    final params = (decoded['params'] is Map)
        ? Map<String, dynamic>.from(decoded['params'] as Map)
        : <String, dynamic>{};

    if (method is! String || method.isEmpty) {
      debugPrint('JsBridge: missing method name');
      return;
    }

    if (!await _isOriginAllowed()) {
      debugPrint('JsBridge: dropped call to "$method" from disallowed origin');
      final cb = params['callbackId'];
      if (cb is String) {
        await _rejectCallback(cb, BridgeErrorCodes.origin, 'Origin not allowed');
      }
      return;
    }

    final inboundEvent = _findInboundEvent(method);
    if (inboundEvent != null) {
      _handleInboundEvent(inboundEvent, params);
      return;
    }

    final isAllowedMethod = config.jsBridge.methods.any(
      (m) => m.split('(').first == method,
    );
    if (!isAllowedMethod) {
      debugPrint('JsBridge: method "$method" not in jsBridge.methods allowlist');
      return;
    }

    await _dispatch(method, params);
  }

  Future<bool> _isOriginAllowed() async {
    if (!config.jsBridge.secureOriginOnly) return true;
    final url = await controller.currentUrl();
    if (url == null) return false;
    final host = Uri.tryParse(url)?.host;
    if (host == null) return false;
    return config.security.restrictToHosts.contains(host);
  }

  InboundEvent? _findInboundEvent(String method) {
    for (final e in config.jsBridge.inboundEvents) {
      if (e.event == method) return e;
    }
    return null;
  }

  void _handleInboundEvent(InboundEvent event, Map<String, dynamic> params) {
    final action = event.action;
    if (action.startsWith('navigate:')) {
      final route = _interpolate(action.substring('navigate:'.length), params);
      if (!context.mounted) return;
      context.go(route);
    } else if (action.startsWith('ui.toast:')) {
      final message = _interpolate(action.substring('ui.toast:'.length), params);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } else {
      debugPrint('JsBridge: unhandled inbound action "$action"');
    }
  }

  /// Resolves `{key}` placeholders against [params].
  String _interpolate(String template, Map<String, dynamic> params) {
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final key = m.group(1)!;
      return (params[key] ?? '').toString();
    });
  }

  Future<void> _dispatch(String method, Map<String, dynamic> params) async {
    final callbackId = params['callbackId'] as String?;
    try {
      switch (method) {
        case 'scanBarcode':
          final v = await _platform.invokeMethod<String>('scanBarcode');
          await _resolveCallback(callbackId, v ?? '');
          break;

        case 'share':
          final text = (params['text'] as String?) ?? '';
          await SharePlus.instance.share(ShareParams(text: text));
          await _resolveCallback(callbackId, true);
          break;

        case 'getDeviceInfo':
          final info = await DeviceInfoPlugin().androidInfo;
          await _resolveCallback(callbackId, {
            'os': 'Android',
            'release': info.version.release,
            'sdkInt': info.version.sdkInt,
            'manufacturer': info.manufacturer,
            'model': info.model,
            'isPhysical': info.isPhysicalDevice,
            'fingerprint': info.fingerprint,
          });
          break;

        case 'downloadBlob':
          final result = await _platform.invokeMethod<Object?>('downloadBlob', {
            'base64data': params['base64data'],
            'filename': params['filename'],
            'mimeType': params['mimeType'],
          });
          await _resolveCallback(callbackId, result);
          break;

        case 'openExternal':
          final raw = (params['url'] as String?) ?? '';
          final uri = Uri.tryParse(raw);
          if (uri == null) {
            await _rejectCallback(callbackId, BridgeErrorCodes.args, 'Invalid URL');
            return;
          }
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            await _resolveCallback(callbackId, true);
          } else {
            await _rejectCallback(callbackId, BridgeErrorCodes.unsupported, 'Cannot launch URL');
          }
          break;

        case 'registerHttpDownload':
          final url = (params['url'] as String?) ?? '';
          if (url.isEmpty || Uri.tryParse(url) == null) {
            await _rejectCallback(callbackId, BridgeErrorCodes.args, 'Invalid URL');
            return;
          }
          final result = await _platform.invokeMethod<Object?>(
            'registerHttpDownload',
            {
              'url': url,
              'userAgent': params['userAgent'],
              'contentDisposition': params['contentDisposition'],
              'mimeType': params['mimeType'],
            },
          );
          await _resolveCallback(callbackId, result);
          break;

        default:
          await _rejectCallback(callbackId, BridgeErrorCodes.unsupported, 'Unknown method "$method"');
      }
    } on PlatformException catch (e) {
      await _rejectCallback(callbackId, e.code, e.message ?? 'Platform error');
    } catch (e, st) {
      if (kDebugMode) debugPrint('JsBridge dispatch failed for $method: $e\n$st');
      await _rejectCallback(callbackId, BridgeErrorCodes.internal, '$e');
    }
  }

  Future<void> _resolveCallback(String? callbackId, Object? result) async {
    if (callbackId == null) return;
    final encodedId = jsonEncode(callbackId);
    final encodedResult = jsonEncode(result);
    final name = jsonEncode(config.jsBridge.name);
    await controller.runJavaScript(
      'window[$name].resolveCallback($encodedId, $encodedResult);',
    );
  }

  Future<void> _rejectCallback(String? callbackId, String code, String message) async {
    if (callbackId == null) return;
    final encodedId = jsonEncode(callbackId);
    final encodedError = jsonEncode({'code': code, 'message': message});
    final name = jsonEncode(config.jsBridge.name);
    await controller.runJavaScript(
      'window[$name].rejectCallback($encodedId, $encodedError);',
    );
  }
}
