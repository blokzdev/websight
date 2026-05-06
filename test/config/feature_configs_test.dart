import 'package:flutter_test/flutter_test.dart';
import 'package:websight/config/feature_configs.dart';

void main() {
  group('SplashFeature', () {
    test('disabled by default when section missing', () {
      final s = SplashFeature.fromMap(null);
      expect(s.enabled, isFalse);
      expect(s.timeoutMs, 1500);
      expect(s.fadeOutMs, 300);
      expect(s.imageAsset, isNull);
      expect(s.backgroundColor, isNull);
      expect(s.tagline, isNull);
    });

    test('reads enabled + timeout_ms', () {
      final s = SplashFeature.fromMap({'enabled': true, 'timeout_ms': 2500});
      expect(s.enabled, isTrue);
      expect(s.timeoutMs, 2500);
      expect(s.fadeOutMs, 300);
    });

    test('normalizes image_asset path and reads background + tagline', () {
      final s = SplashFeature.fromMap({
        'enabled': true,
        'fade_out_ms': 500,
        'image_asset': 'splash/logo.png',
        'background_color': '#0B0B0C',
        'tagline': 'Loading…',
      });
      expect(s.fadeOutMs, 500);
      expect(s.imageAsset, 'assets/splash/logo.png');
      expect(s.backgroundColor, '#0B0B0C');
      expect(s.tagline, 'Loading…');
    });

    test('keeps image_asset paths that already include assets/ prefix', () {
      final s = SplashFeature.fromMap({
        'image_asset': 'assets/splash/hero.svg',
      });
      expect(s.imageAsset, 'assets/splash/hero.svg');
    });

    test('treats empty image_asset as null', () {
      final s = SplashFeature.fromMap({'image_asset': ''});
      expect(s.imageAsset, isNull);
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

  group('UnofficialDisclaimerFeature', () {
    test('disabled by default with fully-formed defaults when section absent',
        () {
      final d = UnofficialDisclaimerFeature.fromMap(null);
      expect(d.enabled, isFalse);
      expect(d.title, isNotEmpty);
      expect(d.body, isNotEmpty);
      expect(d.acceptLabel, isNotEmpty);
      expect(d.declineLabel, isNotEmpty);
      expect(d.requireAccept, isTrue);
    });

    test('reads enabled + custom strings', () {
      final d = UnofficialDisclaimerFeature.fromMap({
        'enabled': true,
        'title': 'Heads up',
        'body': 'Personal use only.',
        'accept_label': 'OK',
        'decline_label': 'Quit',
        'require_accept': false,
      });
      expect(d.enabled, isTrue);
      expect(d.title, 'Heads up');
      expect(d.body, 'Personal use only.');
      expect(d.acceptLabel, 'OK');
      expect(d.declineLabel, 'Quit');
      expect(d.requireAccept, isFalse);
    });

    test('bodyDigest is stable for the same body and changes when body changes',
        () {
      final a = UnofficialDisclaimerFeature.fromMap({'body': 'Same text.'});
      final b = UnofficialDisclaimerFeature.fromMap({'body': 'Same text.'});
      final c =
          UnofficialDisclaimerFeature.fromMap({'body': 'Different text.'});
      expect(a.bodyDigest, b.bodyDigest);
      expect(a.bodyDigest, isNot(c.bodyDigest));
    });

    test('bodyDigest is whitespace-insensitive at the edges', () {
      final a =
          UnofficialDisclaimerFeature.fromMap({'body': '  hello world  '});
      final b = UnofficialDisclaimerFeature.fromMap({'body': 'hello world'});
      expect(a.bodyDigest, b.bodyDigest);
    });
  });

  group('LegalFeature', () {
    test('returns disabled disclaimer when section absent', () {
      final l = LegalFeature.fromMap(null);
      expect(l.unofficialDisclaimer.enabled, isFalse);
    });

    test('routes nested map into UnofficialDisclaimerFeature', () {
      final l = LegalFeature.fromMap({
        'unofficial_disclaimer': {'enabled': true, 'title': 'X'},
      });
      expect(l.unofficialDisclaimer.enabled, isTrue);
      expect(l.unofficialDisclaimer.title, 'X');
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
        'billing': {
          'inapp_enabled': true,
          'product_ids': ['pro']
        },
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

  group('SystemUiFeature', () {
    test('defaults to edge_to_edge with transparent bars', () {
      final s = SystemUiFeature.fromMap(null);
      expect(s.mode, 'edge_to_edge');
      expect(s.isEdgeToEdge, isTrue);
      expect(s.statusBar.transparent, isTrue);
      expect(s.statusBar.iconBrightness, 'auto');
      expect(s.navigationBar.transparent, isTrue);
      expect(s.injectSafeAreaCss, isTrue);
    });

    test('default mode keeps bars opaque unless explicitly transparent', () {
      final s = SystemUiFeature.fromMap(<String, dynamic>{'mode': 'default'});
      expect(s.mode, 'default');
      expect(s.isEdgeToEdge, isFalse);
      expect(s.statusBar.transparent, isFalse);
      expect(s.navigationBar.transparent, isFalse);
    });

    test('explicit per-bar overrides take precedence', () {
      final s = SystemUiFeature.fromMap(<String, dynamic>{
        'mode': 'edge_to_edge',
        'status_bar': {
          'visible': false,
          'transparent': false,
          'icon_brightness': 'light',
        },
        'navigation_bar': {'visible': true, 'icon_brightness': 'dark'},
        'inject_safe_area_css': false,
      });
      expect(s.statusBar.visible, isFalse);
      expect(s.statusBar.transparent, isFalse);
      expect(s.statusBar.iconBrightness, 'light');
      expect(s.navigationBar.iconBrightness, 'dark');
      expect(s.injectSafeAreaCss, isFalse);
    });

    test('immersive_sticky / leanback report isImmersive', () {
      expect(
        SystemUiFeature.fromMap(<String, dynamic>{'mode': 'immersive_sticky'})
            .isImmersive,
        isTrue,
      );
      expect(
        SystemUiFeature.fromMap(<String, dynamic>{'mode': 'leanback'})
            .isImmersive,
        isTrue,
      );
      expect(SystemUiFeature.fromMap(null).isImmersive, isFalse);
    });
  });

  group('MultiWindowFeature', () {
    test('defaults to enabled with auto-close + parent reload', () {
      final m = MultiWindowFeature.fromMap(null);
      expect(m.enabled, isTrue);
      expect(m.closeOnParentHost, isTrue);
      expect(m.reloadParentOnClose, isTrue);
    });

    test('respects explicit disable', () {
      final m = MultiWindowFeature.fromMap(<String, dynamic>{
        'enabled': false,
        'close_on_parent_host': false,
        'reload_parent_on_close': false,
      });
      expect(m.enabled, isFalse);
      expect(m.closeOnParentHost, isFalse);
      expect(m.reloadParentOnClose, isFalse);
    });
  });

  group('FullscreenVideoFeature', () {
    test('defaults to enabled, no orientation lock', () {
      final f = FullscreenVideoFeature.fromMap(null);
      expect(f.enabled, isTrue);
      expect(f.lockLandscape, isFalse);
    });

    test('reads lock_landscape', () {
      final f = FullscreenVideoFeature.fromMap(<String, dynamic>{
        'lock_landscape': true,
      });
      expect(f.lockLandscape, isTrue);
    });
  });

  group('WebViewPermissionsFeature', () {
    test('defaults: camera/mic/geo allowed; protected media denied', () {
      final p = WebViewPermissionsFeature.fromMap(null);
      expect(p.allowCamera, isTrue);
      expect(p.allowMicrophone, isTrue);
      expect(p.allowGeolocation, isTrue);
      expect(p.allowProtectedMedia, isFalse);
      expect(p.retainGeolocation, isFalse);
    });

    test('honours per-permission opt-outs', () {
      final p = WebViewPermissionsFeature.fromMap(<String, dynamic>{
        'allow_camera': false,
        'allow_microphone': false,
        'allow_geolocation': false,
        'retain_geolocation': true,
      });
      expect(p.allowCamera, isFalse);
      expect(p.allowMicrophone, isFalse);
      expect(p.allowGeolocation, isFalse);
      expect(p.retainGeolocation, isTrue);
    });
  });

  group('WebSightFeatures.fromRaw — new sections', () {
    test('reads system_ui under flutter_ui', () {
      final raw = <String, dynamic>{
        'flutter_ui': {
          'system_ui': {
            'mode': 'immersive_sticky',
            'status_bar': {'icon_brightness': 'light'},
          },
        },
      };
      final f = WebSightFeatures.fromRaw(raw, appName: 'X');
      expect(f.systemUi.mode, 'immersive_sticky');
      expect(f.systemUi.statusBar.iconBrightness, 'light');
    });

    test('reads multi_window + fullscreen_video under webview_settings', () {
      final raw = <String, dynamic>{
        'webview_settings': {
          'multi_window': {'enabled': false},
          'fullscreen_video': {'enabled': true, 'lock_landscape': true},
        },
      };
      final f = WebSightFeatures.fromRaw(raw, appName: 'X');
      expect(f.multiWindow.enabled, isFalse);
      expect(f.fullscreenVideo.enabled, isTrue);
      expect(f.fullscreenVideo.lockLandscape, isTrue);
    });

    test('reads permissions.webview', () {
      final raw = <String, dynamic>{
        'permissions': {
          'webview': {
            'allow_camera': false,
            'allow_protected_media': true,
          },
        },
      };
      final f = WebSightFeatures.fromRaw(raw, appName: 'X');
      expect(f.webviewPermissions.allowCamera, isFalse);
      expect(f.webviewPermissions.allowProtectedMedia, isTrue);
      // Defaults preserved for keys not present.
      expect(f.webviewPermissions.allowMicrophone, isTrue);
      expect(f.webviewPermissions.allowGeolocation, isTrue);
    });

    test('missing sections fall back to immersive defaults', () {
      final f = WebSightFeatures.fromRaw(<String, dynamic>{}, appName: 'X');
      expect(f.systemUi.mode, 'edge_to_edge');
      expect(f.multiWindow.enabled, isTrue);
      expect(f.fullscreenVideo.enabled, isTrue);
      expect(f.webviewPermissions.allowCamera, isTrue);
    });
  });
}
