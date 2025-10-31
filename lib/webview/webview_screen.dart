import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/webview/webview_controller.dart' as wc;
import 'package:webview_flutter/webview_flutter.dart';

class WebViewScreen extends StatefulWidget {
  final String initialUrl;
  final RouteConfig routeConfig;

  const WebViewScreen({
    super.key,
    required this.initialUrl,
    required this.routeConfig,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final wc.WebsightWebViewController _websightController;
  late final WebSightConfig _config;

  @override
  void initState() {
    super.initState();
    _config = context.read<WebSightConfig>();
    _websightController = wc.WebsightWebViewController(
      config: _config,
      routeConfig: widget.routeConfig,
      context: context,
    );
    _websightController.controller.loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  void dispose() {
    _websightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using PopScope with the non-deprecated onPopInvokedWithResult.
    return PopScope(
      canPop: false, // We will manage all pop events manually.
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // Capture the navigator BEFORE the async gap.
        final navigator = Navigator.of(context);
        final bool canWebViewGoBack =
            await _websightController.controller.canGoBack();

        if (canWebViewGoBack) {
          _websightController.controller.goBack();
        } else {
          final bool confirmExit =
              _config.behaviorOverrides.backButton.confirmBeforeExit;

          if (confirmExit) {
            // To satisfy the linter, we check `context.mounted` before the async gap.
            if (!context.mounted) return;

            final bool? shouldPop = await showDialog<bool>(
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

            if (shouldPop ?? false) {
              navigator.pop();
            }
          } else {
            navigator.pop();
          }
        }
      },
      child: ChangeNotifierProvider.value(
        value: _websightController,
        child: Consumer<wc.WebsightWebViewController>(
          builder: (context, controller, child) {
            return RefreshIndicator(
              onRefresh: () => controller.reload(),
              notificationPredicate: (notification) {
                return widget.routeConfig.pullToRefresh;
              },
              child: Stack(
                children: [
                  WebViewWidget(controller: controller.controller),
                  if (controller.isLoading) const LinearProgressIndicator(),
                  if (controller.webError != null)
                    _buildErrorScreen(controller),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorScreen(wc.WebsightWebViewController controller) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                'Page Load Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              Text(
                'Could not load the page. Error: ${controller.webError?.description ?? 'Unknown Error'}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => controller.reload(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
