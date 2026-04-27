import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/feature_configs.dart';

void main() {
  group('SplashFeature', () {
    test('disabled by default when section missing', () {
      final s = SplashFeature.fromMap(null);
      expect(s.enabled, isFalse);
      expect(s.timeoutMs, 1500);
    });

    test('reads enabled + timeout_ms', () {
      final s = SplashFeature.fromMap({'enabled': true, 'timeout_ms': 2500});
      expect(s.enabled, isTrue);
      expect(s.timeoutMs, 2500);
    });
  });

  group('OfflineHtmlFeature', () {
    test('normalizes asset paths without assets/ prefix', () {
      final o = OfflineHtmlFeature.fromMap({
        'fallback_when_offline': true,
        'index_asset': 'offline/index.html',
      });
      expect(o.fallbackWhenOffline, isTrue);
      expect(o.indexAsset, 'assets/offline/index.html');
    });

    test('keeps asset paths that already include the prefix', () {
      final o = OfflineHtmlFeature.fromMap({
        'index_asset': 'assets/foo/page.html',
      });
      expect(o.indexAsset, 'assets/foo/page.html');
    });
  });

  group('UserAgentMode', () {
    test('defaults to system when section missing', () {
      final ua = UserAgentMode.fromMap(null);
      expect(ua.mode, 'system');
      expect(ua.append, '');
      expect(ua.custom, isNull);
    });

    test('reads append mode + suffix', () {
      final ua = UserAgentMode.fromMap({
        'user_agent': {'mode': 'append', 'append': ' WebSight/1.0'}
      });
      expect(ua.mode, 'append');
      expect(ua.append, ' WebSight/1.0');
    });
  });

  group('FileUploadsFeature', () {
    test('enabled by default', () {
      final f = FileUploadsFeature.fromMap(null);
      expect(f.enabled, isTrue);
      expect(f.captureCamera, isTrue);
      expect(f.mimeTypes, ['*/*']);
    });

    test('respects explicit mime_types', () {
      final f = FileUploadsFeature.fromMap({
        'enabled': true,
        'capture_camera': false,
        'mime_types': ['image/*', 'application/pdf'],
      });
      expect(f.mimeTypes, ['image/*', 'application/pdf']);
      expect(f.captureCamera, isFalse);
    });
  });

  group('DownloadsFeature', () {
    test('all flags default-on when section missing', () {
      final d = DownloadsFeature.fromMap(null);
      expect(d.enabled, isTrue);
      expect(d.useDownloadManager, isTrue);
      expect(d.supportBlobUrls, isTrue);
    });

    test('honors explicit opt-out flags', () {
      final d = DownloadsFeature.fromMap({
        'enabled': false,
        'use_android_download_manager': false,
        'support_blob_urls': false,
      });
      expect(d.enabled, isFalse);
      expect(d.useDownloadManager, isFalse);
      expect(d.supportBlobUrls, isFalse);
    });
  });

  group('BillingFeature', () {
    test('disabled and empty by default', () {
      final b = BillingFeature.fromMap(null);
      expect(b.enabled, isFalse);
      expect(b.productIds, isEmpty);
    });

    test('reads product_ids list', () {
      final b = BillingFeature.fromMap({
        'inapp_enabled': true,
        'product_ids': ['pro_monthly', 'pro_yearly'],
      });
      expect(b.enabled, isTrue);
      expect(b.productIds, ['pro_monthly', 'pro_yearly']);
    });
  });

  group('BottomTabsFeature', () {
    test('drops items missing a route', () {
      final t = BottomTabsFeature.fromMap({
        'visible': true,
        'items': [
          {'label': 'Home', 'icon': 'Icons.home', 'route': '/web/home'},
          {'label': 'Empty'}, // missing route -> dropped
        ],
      });
      expect(t.items.length, 1);
      expect(t.items.first.route, '/web/home');
    });
  });

  group('DrawerFeature', () {
    test('falls back to app name when header.title missing', () {
      final d = DrawerFeature.fromMap(null, 'WebSight');
      expect(d.headerTitle, 'WebSight');
      expect(d.items, isEmpty);
    });

    test('parses items with route or action', () {
      final d = DrawerFeature.fromMap({
        'visible': true,
        'header': {'title': 'Hi'},
        'items': [
          {'title': 'Home', 'icon': 'home', 'route': '/web/home'},
          {'title': 'Scan', 'icon': 'qr', 'action': 'bridge.scanBarcode'},
        ],
      }, 'AppName');
      expect(d.items.length, 2);
      expect(d.items[0].route, '/web/home');
      expect(d.items[1].action, 'bridge.scanBarcode');
    });
  });

  group('WebSightFeatures.fromRaw', () {
    test('builds full feature graph from a representative YAML map', () {
      final raw = <String, dynamic>{
        'splash': {'enabled': true, 'timeout_ms': 800},
        'offline_local_html': {'fallback_when_offline': true},
        'webview_settings': {
          'custom_user_scripts': {
            'inject_css': {
              'enabled': true,
              'asset_path': 'website/css/custom.css',
            },
          },
        },
        'app': {
          'user_agent': {'mode': 'append', 'append': ' WebSight/1.0'}
        },
        'billing': {'inapp_enabled': true, 'product_ids': ['pro']},
        'flutter_ui': {
          'layout': {
            'bottom_tabs': {
              'visible': true,
              'items': [
                {'label': 'A', 'icon': 'home', 'route': '/web/a'},
              ],
            },
            'floating_action_button': {
              'visible': true,
              'icon': 'Icons.add',
              'action': 'navigate:/web/new',
            },
            'drawer': {'visible': true},
          },
        },
        'behavior_overrides': {
          'error_pages': {'show_offline_page': true, 'retry_button': true},
        },
      };

      final f = WebSightFeatures.fromRaw(raw, appName: 'Demo');
      expect(f.splash.enabled, isTrue);
      expect(f.splash.timeoutMs, 800);
      expect(f.offline.fallbackWhenOffline, isTrue);
      expect(f.userScripts.injectCssAsset, 'assets/website/css/custom.css');
      expect(f.userAgent.mode, 'append');
      expect(f.billing.productIds, ['pro']);
      expect(f.bottomTabs.visible, isTrue);
      expect(f.bottomTabs.items.single.route, '/web/a');
      expect(f.fab.action, 'navigate:/web/new');
      expect(f.drawer.headerTitle, 'Demo');
      expect(f.errorPages.retryButton, isTrue);
    });
  });
}
