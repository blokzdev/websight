import 'package:flutter/services.dart';

class MethodChannelBridge {
  static const MethodChannel _channel =
      MethodChannel('websight/method_channel');

  static void initialize() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'share':
        // Handle share
        break;
      case 'getDeviceInfo':
        return {'os': 'Android', 'version': '13'};
      case 'downloadBlob':
        // Handle download
        break;
      case 'openExternal':
        // Handle open external
        break;
      case 'scanBarcode':
        // This will be initiated from Flutter, not called from native.
        break;
      default:
        throw PlatformException(
          code: 'Unimplemented',
          details: "Method ${call.method} not implemented.",
        );
    }
  }
}
