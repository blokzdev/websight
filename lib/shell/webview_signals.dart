import 'package:flutter/foundation.dart';

/// Cross-screen broadcaster used by the AppBar / drawer / FAB action
/// dispatcher to ask the currently-visible WebView to do something
/// (reload, navigate back). The signal layer is intentionally tiny — a
/// monotonically increasing counter — so any number of subscribers can
/// react without coupling to a specific WebView controller instance.
///
/// `WebViewSignals` is provided once at app startup (see `main.dart`) and
/// the active `WebViewScreen` listens for ticks. Pages outside of any
/// WebView (e.g. native screens) silently no-op when the signal fires.
class WebViewSignals extends ChangeNotifier {
  int _reloadTick = 0;
  int _backTick = 0;

  int get reloadTick => _reloadTick;
  int get backTick => _backTick;

  void requestReload() {
    _reloadTick++;
    notifyListeners();
  }

  void requestBack() {
    _backTick++;
    notifyListeners();
  }
}
