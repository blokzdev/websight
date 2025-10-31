import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:websight/config/webview_config.dart';

class JsBridge {
  final WebViewController controller;
  final WebSightConfig config;
  final MethodChannel _platformChannel =
      const MethodChannel('websight/method_channel');
  final BuildContext context; // For navigation and showing SnackBars

  JsBridge(
      {required this.controller,
      required this.config,
      required this.context});

  void inject() async {
    final jsContent = await rootBundle.loadString('assets/websight.js');
    await controller.runJavaScript(jsContent);
    await controller.runJavaScript(
        "window.${config.jsBridge.name} = new WebSightBridgeInternal('${config.jsBridge.name}');");
  }

  void handleMessage(JavaScriptMessage message) {
    try {
      final decodedMessage = json.decode(message.message);
      final method = decodedMessage['method'];
      final params = decodedMessage['params'];

      // Check for outbound methods (JS calling native)
      if (config.jsBridge.methods
          .any((m) => m.startsWith(method.split('(').first))) {
        _invokeMethod(method, params);
        return;
      }
      // Check for inbound events (JS dispatching events to native)
      InboundEvent? inboundEvent;
      try {
        inboundEvent =
            config.jsBridge.inboundEvents.firstWhere((e) => e.event == method);
      } catch (e) {
        // This is fine, means no event was found
      }

      if (inboundEvent != null) {
        _handleInboundEvent(inboundEvent, params);
        return;
      }

      debugPrint('JS Bridge: Method or event "$method" not configured.');
    } catch (e) {
      debugPrint('Error handling JS message: $e');
    }
  }

  void _invokeMethod(String method, dynamic params) {
    switch (method) {
      case 'scanBarcode':
        _handleScanBarcode(params['callbackId']);
        break;
      case 'share':
        _handleShare(params['text']);
        break;
      case 'getDeviceInfo':
        _handleGetDeviceInfo(params['callbackId']);
        break;
      case 'downloadBlob':
        _handleDownloadBlob(params);
        break;
      case 'openExternal':
        _handleOpenExternal(params['url']);
        break;
    }
  }

  void _handleInboundEvent(InboundEvent event, dynamic params) {
    if (event.action.startsWith('navigate:')) {
      final route = event.action.split(':').last;
      context.go(route);
    } else if (event.action.startsWith('ui.toast:')) {
      final message = params['message'] ?? 'Default message';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleScanBarcode(String callbackId) async {
    try {
      final result = await _platformChannel.invokeMethod('scanBarcode');
      _sendResultToJs(callbackId, result);
    } catch (e) {
      _sendErrorToJs(callbackId, e.toString());
    }
  }

  Future<void> _handleShare(String text) async {
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (e) {
      debugPrint('Error sharing: $e');
    }
  }

  Future<void> _handleGetDeviceInfo(String callbackId) async {
    try {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      _sendResultToJs(callbackId, {
        'os': 'Android',
        'version': androidInfo.version.release,
        'sdk': androidInfo.version.sdkInt,
      });
    } catch (e) {
      _sendErrorToJs(callbackId, e.toString());
    }
  }

  Future<void> _handleDownloadBlob(dynamic params) async {
    try {
      await _platformChannel.invokeMethod('downloadBlob', {
        'base64data': params['base64data'],
        'filename': params['filename'],
        'mimeType': params['mimeType'],
      });
    } catch (e) {
      debugPrint('Error downloading blob: $e');
    }
  }

  Future<void> _handleOpenExternal(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _sendResultToJs(String callbackId, dynamic result) {
    final encodedResult = json.encode(result);
    controller.runJavaScript(
        "window.${config.jsBridge.name}.resolveCallback('$callbackId', $encodedResult);");
  }

  void _sendErrorToJs(String callbackId, String error) {
    final encodedError = json.encode(error);
    controller.runJavaScript(
        "window.${config.jsBridge.name}.rejectCallback('$callbackId', $encodedError);");
  }
}
