import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:websight/config/feature_configs.dart';
import 'package:websight/config/webview_config.dart';
import 'package:websight/lifecycle/fcm_controller.dart';
import 'package:websight/shell/action_dispatcher.dart';
import 'package:websight/utils/helpers.dart';

/// Single native screen used for every `kind: native` route.
///
/// v1 ships two variants:
///
///   * `/native/settings` (or any path ending in `/settings`) renders a real
///     read-only settings surface: app identity, theme, notification +
///     analytics flags, FCM token (if available), billing products, and a
///     small list of "Privacy / Terms / Rate the app" links resolved against
///     the route table. There is no per-app business state here — that is
///     what your forked subclass is for.
///
///   * Every other `/native/*` route renders a clearly-labeled placeholder so
///     it is obvious the screen is intentional but unimplemented. Replace
///     this widget in your fork with the real native UI for that route.
class ConfigurableNativeScreen extends StatelessWidget {
  const ConfigurableNativeScreen({super.key, required this.route});

  final RouteConfig route;

  @override
  Widget build(BuildContext context) {
    final isSettings = route.path == '/native/settings' ||
        route.path.endsWith('/settings');
    return isSettings
        ? const _NativeSettingsPage()
        : _NativePlaceholderPage(route: route);
  }
}

class _NativePlaceholderPage extends StatelessWidget {
  const _NativePlaceholderPage({required this.route});

  final RouteConfig route;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconForString(route.icon ?? 'info'),
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(route.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'This is a native placeholder for `${route.path}`.\n'
              'Replace ConfigurableNativeScreen in your fork with the real '
              'screen for this route.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _NativeSettingsPage extends StatelessWidget {
  const _NativeSettingsPage();

  @override
  Widget build(BuildContext context) {
    final config = context.watch<WebSightConfig>();
    final features = context.watch<WebSightFeatures>();
    final fcm = context.watch<FcmController>();
    final theme = Theme.of(context);
    final dispatcher = ActionDispatcher();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _Section(title: 'App'),
        _InfoTile(
          icon: Icons.info_outline,
          label: 'Name',
          value: config.app.name,
        ),
        _InfoTile(
          icon: Icons.public,
          label: 'Host',
          value: config.app.host,
        ),
        _InfoTile(
          icon: Icons.dark_mode_outlined,
          label: 'Theme',
          value:
              '${config.flutterUi.theme.brightness} · primary ${config.flutterUi.theme.primary}',
        ),

        const SizedBox(height: 8),
        _Section(title: 'Notifications'),
        _InfoTile(
          icon: Icons.notifications_outlined,
          label: 'Permission prompt',
          value: config.notifications.postNotificationsPermission
              ? 'Requested at launch'
              : 'Disabled',
        ),
        _InfoTile(
          icon: Icons.cloud_outlined,
          label: 'FCM',
          value: config.notifications.fcmEnabled
              ? (fcm.initialized
                  ? (fcm.token != null
                      ? 'Token: ${_truncate(fcm.token!)}'
                      : 'Initialized, no token yet')
                  : 'Pending init')
              : 'Disabled',
        ),

        const SizedBox(height: 8),
        _Section(title: 'Privacy & monetization'),
        _InfoTile(
          icon: Icons.analytics_outlined,
          label: 'Analytics',
          value: config.analyticsCrash.analytics ? 'On' : 'Off',
        ),
        _InfoTile(
          icon: Icons.bug_report_outlined,
          label: 'Crashlytics',
          value: config.analyticsCrash.crashlytics ? 'On' : 'Off',
        ),
        _InfoTile(
          icon: Icons.shopping_cart_outlined,
          label: 'In-app purchases',
          value: !features.billing.enabled
              ? 'Disabled'
              : features.billing.productIds.isEmpty
                  ? 'Enabled, no products configured'
                  : '${features.billing.productIds.length} product(s)',
        ),

        if (_visibleLinks(config).isNotEmpty) ...[
          const SizedBox(height: 8),
          _Section(title: 'Links'),
          for (final r in _visibleLinks(config))
            ListTile(
              leading: Icon(
                  iconForString(r.icon ?? _defaultLinkIcon(r.path))),
              title: Text(r.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(r.path),
            ),
        ],

        const SizedBox(height: 8),
        _Section(title: 'About'),
        ListTile(
          leading: const Icon(Icons.thumb_up_off_alt),
          title: const Text('Rate this app'),
          onTap: () => dispatcher.dispatch(context, 'store.rate'),
        ),
        ListTile(
          leading: const Icon(Icons.numbers_outlined),
          title: const Text('Build'),
          subtitle: Text(
            'Material ${config.flutterUi.theme.useMaterial3 ? '3' : '2'} · '
            'host ${config.app.host}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  /// Surface "/web/privacy", "/web/terms", and any explicitly tagged routes
  /// that look like static-info pages, so the integrator gets a Privacy /
  /// Terms entry on Settings without manually wiring them.
  List<RouteConfig> _visibleLinks(WebSightConfig config) {
    return config.routes.where((r) {
      if (r.kind != 'webview') return false;
      final p = r.path.toLowerCase();
      return p.endsWith('/privacy') || p.endsWith('/terms') ||
          p.endsWith('/legal') || p.endsWith('/about');
    }).toList(growable: false);
  }

  String _defaultLinkIcon(String path) {
    if (path.contains('privacy')) return 'privacy_tip_outlined';
    if (path.contains('terms')) return 'info';
    return 'info';
  }

  String _truncate(String s) =>
      s.length <= 18 ? s : '${s.substring(0, 6)}…${s.substring(s.length - 8)}';
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
      dense: true,
    );
  }
}
