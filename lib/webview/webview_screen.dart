import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/shell/webview_signals.dart';
import 'package:websight/utils/helpers.dart';
import 'package:websight/webview/webview_controller.dart' as wc;

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({
    super.key,
    required this.initialUrl,
    required this.routeConfig,
  });

  final String initialUrl;
  final RouteConfig routeConfig;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final wc.WebsightWebViewController _websightController;
  late final WebSightConfig _config;
  late final WebSightFeatures _features;
  WebViewSignals? _signals;
  int _lastReloadTick = 0;
  int _lastBackTick = 0;

  bool _showSplash = false;
  Timer? _splashTimer;

  @override
  void initState() {
    super.initState();
    _config = context.read<WebSightConfig>();
    _features = context.read<WebSightFeatures>();
    _websightController = wc.WebsightWebViewController(
      config: _config,
      features: _features,
      routeConfig: widget.routeConfig,
      context: context,
    );
    _websightController.controller.loadRequest(Uri.parse(widget.initialUrl));

    _signals = context.read<WebViewSignals>();
    _lastReloadTick = _signals!.reloadTick;
    _lastBackTick = _signals!.backTick;
    _signals!.addListener(_onSignal);

    if (_features.splash.enabled) {
      _showSplash = true;
      _splashTimer = Timer(
        Duration(milliseconds: _features.splash.timeoutMs),
        () {
          if (!mounted) return;
          setState(() => _showSplash = false);
        },
      );
    }
  }

  void _onSignal() {
    final s = _signals;
    if (s == null) return;
    if (s.reloadTick != _lastReloadTick) {
      _lastReloadTick = s.reloadTick;
      _websightController.reload();
    }
    if (s.backTick != _lastBackTick) {
      _lastBackTick = s.backTick;
      _websightController.controller
          .canGoBack()
          .then((canBack) {
        if (canBack) _websightController.controller.goBack();
      });
    }
  }

  @override
  void dispose() {
    _signals?.removeListener(_onSignal);
    _splashTimer?.cancel();
    _websightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handlePop,
      child: ChangeNotifierProvider<wc.WebsightWebViewController>.value(
        value: _websightController,
        child: Consumer<wc.WebsightWebViewController>(
          builder: (context, controller, _) {
            final showOffline = controller.isOffline &&
                _features.errorPages.showOfflinePage;
            final showError = controller.webError != null && !controller.isOffline;

            return RefreshIndicator(
              onRefresh: controller.reload,
              notificationPredicate: (_) => widget.routeConfig.pullToRefresh,
              child: Stack(
                children: [
                  WebViewWidget(controller: controller.controller),
                  if (controller.isLoading)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (showOffline) _OfflineOverlay(features: _features, controller: controller),
                  if (showError) _ErrorOverlay(controller: controller, features: _features),
                  // The splash overlay paints over everything else (including
                  // ad placements) until its timer fires; the fade lets the
                  // page below reveal smoothly.
                  AnimatedSwitcher(
                    duration:
                        Duration(milliseconds: _features.splash.fadeOutMs),
                    child: _showSplash
                        ? _SplashOverlay(splash: _features.splash)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _handlePop(bool didPop, dynamic _) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final canBack = await _websightController.controller.canGoBack();
    if (canBack) {
      await _websightController.controller.goBack();
      return;
    }
    final confirmExit = _config.behaviorOverrides.backButton.confirmBeforeExit;
    if (!confirmExit) {
      navigator.pop();
      return;
    }
    if (!context.mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Exit'),
        content: const Text('Are you sure you want to exit the app?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    if (result ?? false) navigator.pop();
  }
}

class _SplashOverlay extends StatelessWidget {
  const _SplashOverlay({required this.splash});

  final SplashFeature splash;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = parseColor(splash.backgroundColor,
        fallback: theme.colorScheme.surface);
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : Colors.black;

    return Container(
      key: const ValueKey<String>('websight.splash'),
      color: bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (splash.imageAsset != null) ...[
                Image.asset(
                  splash.imageAsset!,
                  width: 144,
                  height: 144,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: fg.withOpacity(0.6),
                    size: 56,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              if (splash.tagline != null && splash.tagline!.isNotEmpty) ...[
                Text(
                  splash.tagline!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(color: fg),
                ),
                const SizedBox(height: 24),
              ],
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay({required this.features, required this.controller});

  final WebSightFeatures features;
  final wc.WebsightWebViewController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: theme.colorScheme.error, size: 56),
              const SizedBox(height: 16),
              Text(
                "You're offline",
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Check your connection and try again.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              if (features.errorPages.retryButton)
                FilledButton.icon(
                  onPressed: controller.reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.controller, required this.features});

  final wc.WebsightWebViewController controller;
  final WebSightFeatures features;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = controller.webError?.description ?? 'Unknown error';
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 56),
              const SizedBox(height: 16),
              Text(
                'Page failed to load',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(desc, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              if (features.errorPages.retryButton)
                FilledButton.icon(
                  onPressed: controller.reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
