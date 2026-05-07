import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:websight/config/feature_configs.dart';

/// Applies the configured `system_ui` block to `SystemChrome`.
///
/// Intent: an integrator's wrapped site should look and feel like a native
/// app — that means the WebView fills the whole window and the system bars
/// either disappear or float transparently over it. This controller centralises
/// the `SystemChrome.setEnabledSystemUIMode` and `setSystemUIOverlayStyle`
/// calls so they're driven by YAML, not scattered through the widget tree.
///
/// Re-apply on theme changes by calling [applyForBrightness] from a
/// listener in your top-level widget.
class SystemChromeController {
  SystemChromeController({required this.feature});

  final SystemUiFeature feature;

  /// Apply the configured mode + overlay style. The bar visibility flags
  /// only matter when [feature.mode] is `default` or `edge_to_edge` — for
  /// the immersive modes Android hides both bars regardless and reveals
  /// them on user interaction (sticky) or never (leanback).
  Future<void> applyForBrightness(Brightness themeBrightness) async {
    final mode = _resolveMode();
    final overlays = _resolveOverlays();
    await SystemChrome.setEnabledSystemUIMode(mode, overlays: overlays);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle(themeBrightness));
  }

  /// Restores the platform default. Call when leaving an immersive context
  /// (e.g. fullscreen video exit) and you don't want to inherit the
  /// previous immersive_sticky setting.
  static Future<void> resetToDefault() async {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  SystemUiMode _resolveMode() {
    switch (feature.mode) {
      case 'immersive_sticky':
        return SystemUiMode.immersiveSticky;
      case 'leanback':
        return SystemUiMode.leanBack;
      case 'edge_to_edge':
        return SystemUiMode.edgeToEdge;
      case 'default':
      default:
        return SystemUiMode.manual;
    }
  }

  /// Bars to keep on-screen when [SystemUiMode.manual] is the resolved mode.
  /// For [SystemUiMode.edgeToEdge] the overlays are always shown; the
  /// transparency is the styling lever, not the visibility flags.
  List<SystemUiOverlay> _resolveOverlays() {
    if (feature.mode == 'immersive_sticky' || feature.mode == 'leanback') {
      return const <SystemUiOverlay>[];
    }
    return <SystemUiOverlay>[
      if (feature.statusBar.visible) SystemUiOverlay.top,
      if (feature.navigationBar.visible) SystemUiOverlay.bottom,
    ];
  }

  SystemUiOverlayStyle _overlayStyle(Brightness themeBrightness) {
    final statusIconBrightness = _iconBrightness(
      feature.statusBar.iconBrightness,
      themeBrightness: themeBrightness,
    );
    final navIconBrightness = _iconBrightness(
      feature.navigationBar.iconBrightness,
      themeBrightness: themeBrightness,
    );
    return SystemUiOverlayStyle(
      statusBarColor: feature.statusBar.transparent ? Colors.transparent : null,
      // iOS uses statusBarBrightness to mean "the brightness OF the status
      // bar background"; on Android it's a no-op. We still set it so the
      // intent is captured if/when iOS support lands.
      statusBarBrightness: statusIconBrightness == Brightness.light
          ? Brightness.dark
          : Brightness.light,
      statusBarIconBrightness: statusIconBrightness,
      systemNavigationBarColor:
          feature.navigationBar.transparent ? Colors.transparent : null,
      systemNavigationBarIconBrightness: navIconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    );
  }

  /// Resolve a configured `auto | light | dark` value. `auto` derives from
  /// the active theme — a dark theme wants light icons (so they're visible
  /// against a dark surface drawn under the bar) and vice versa.
  static Brightness _iconBrightness(
    String configured, {
    required Brightness themeBrightness,
  }) {
    switch (configured) {
      case 'light':
        return Brightness.light;
      case 'dark':
        return Brightness.dark;
      case 'auto':
      default:
        return themeBrightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark;
    }
  }

  @visibleForTesting
  static Brightness iconBrightnessForTest(
    String configured, {
    required Brightness themeBrightness,
  }) =>
      _iconBrightness(configured, themeBrightness: themeBrightness);
}
