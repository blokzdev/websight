import 'package:flutter_test/flutter_test.dart';
import 'package:websight/webview/popup_window.dart';

/// Lightweight unit coverage for the popup window helpers. The full
/// [PopupWindow] widget needs a platform WebView to exercise the navigation
/// rules, which isn't viable in pure-Dart tests; the navigation logic lives
/// in `_onNavigationRequest` inside the screen and is verified manually as
/// part of the on-device end-to-end checklist.
void main() {
  group('popupOpenInterceptorJs', () {
    test('embeds the configured bridge name', () {
      final js = popupOpenInterceptorJs(bridgeName: 'WebSightBridge');
      expect(js.contains('window["WebSightBridge"]'), isTrue);
    });

    test('routes window.open URLs into the bridge as openPopup', () {
      final js = popupOpenInterceptorJs(bridgeName: 'B');
      expect(js.contains('method: "openPopup"'), isTrue);
      expect(js.contains('window.open = function'), isTrue);
    });

    test('guards against double-installation', () {
      final js = popupOpenInterceptorJs(bridgeName: 'B');
      expect(js.contains('__websightOpenIntercepted'), isTrue);
    });

    test('falls back to original window.open when called with no URL', () {
      final js = popupOpenInterceptorJs(bridgeName: 'B');
      // The shim should still call origOpen for the no-args / non-string case
      // so legitimate `window.open()` blank-tab calls keep working.
      expect(js.contains('origOpen.apply(window, arguments)'), isTrue);
    });
  });
}
