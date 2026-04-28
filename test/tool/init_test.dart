// ignore_for_file: always_use_package_imports

import 'package:flutter_test/flutter_test.dart';

import '../../tool/init_lib.dart';

void main() {
  group('validateHost', () {
    test('rejects empty / scheme / path / spaces', () {
      expect(validateHost(''), isNotNull);
      expect(validateHost('https://x.com'), isNotNull);
      expect(validateHost('x.com/path'), isNotNull);
      expect(validateHost('x .com'), isNotNull);
    });
    test('rejects single-segment hosts', () {
      expect(validateHost('localhost'), isNotNull);
    });
    test('accepts well-formed hosts', () {
      expect(validateHost('example.com'), isNull);
      expect(validateHost('a.b.c'), isNull);
      expect(validateHost('blockchair.com'), isNull);
    });
  });

  group('validateHomeUrl', () {
    test('requires scheme + matching host', () {
      expect(validateHomeUrl('example.com', host: 'example.com'), isNotNull);
      expect(
        validateHomeUrl('https://other.com/', host: 'example.com'),
        isNotNull,
      );
      expect(
        validateHomeUrl('ftp://example.com/', host: 'example.com'),
        isNotNull,
      );
    });
    test('accepts http and https', () {
      expect(
        validateHomeUrl('https://example.com/', host: 'example.com'),
        isNull,
      );
      expect(
        validateHomeUrl('http://localhost.dev/', host: 'localhost.dev'),
        isNull,
      );
    });
  });

  group('validateApplicationId', () {
    test('rejects single-segment / camelCase / dashes', () {
      expect(validateApplicationId('com'), isNotNull);
      expect(validateApplicationId('com.YourCompany.App'), isNotNull);
      expect(validateApplicationId('com.your-company.app'), isNotNull);
    });
    test('accepts canonical reverse-DNS', () {
      expect(validateApplicationId('com.example.shop'), isNull);
      expect(validateApplicationId('io.foo.bar.baz'), isNull);
    });
  });

  group('validateAdmobAppId', () {
    test('empty is allowed (ads disabled)', () {
      expect(validateAdmobAppId(''), isNull);
    });
    test('rejects unit-id-shaped values', () {
      expect(
        validateAdmobAppId('ca-app-pub-1234567890/1234567890'),
        contains('Unit ID'),
      );
    });
    test('rejects bad prefix or missing tilde', () {
      expect(validateAdmobAppId('foo'), isNotNull);
      expect(validateAdmobAppId('ca-app-pub-1234567890'), isNotNull);
    });
    test('accepts well-formed App IDs', () {
      expect(
        validateAdmobAppId('ca-app-pub-1234567890123456~1234567890'),
        isNull,
      );
    });
  });

  group('validateVersion', () {
    test('rejects bad shapes', () {
      expect(validateVersion(''), isNotNull);
      expect(validateVersion('1.0'), isNotNull);
      expect(validateVersion('1.0.0'), isNotNull);
      expect(validateVersion('v1.0.0+1'), isNotNull);
    });
    test('accepts canonical', () {
      expect(validateVersion('1.0.0+1'), isNull);
      expect(validateVersion('12.34.56+789'), isNull);
    });
  });

  group('validateHexColor', () {
    test('accepts 3/6/8-char with or without #', () {
      expect(validateHexColor('#FFF'), isNull);
      expect(validateHexColor('AABBCC'), isNull);
      expect(validateHexColor('#80112233'), isNull);
    });
    test('rejects bad lengths and non-hex chars', () {
      expect(validateHexColor('#FFFF'), isNotNull);
      expect(validateHexColor('#GGGGGG'), isNotNull);
      expect(validateHexColor(''), isNotNull);
    });
  });

  group('looksThirdParty', () {
    test('matches well-known sites and their subdomains', () {
      expect(looksThirdParty('blockchair.com'), isTrue);
      expect(looksThirdParty('en.wikipedia.org'), isTrue);
      expect(looksThirdParty('github.com'), isTrue);
    });
    test('returns false for arbitrary hosts', () {
      expect(looksThirdParty('myshop.example'), isFalse);
      expect(looksThirdParty('internal.corp'), isFalse);
    });
  });

  WizardAnswers answers({
    String name = 'Demo',
    String host = 'example.com',
    String? admobAppId,
    bool adsEnabled = false,
    bool disclaimerEnabled = false,
  }) {
    return WizardAnswers(
      name: name,
      host: host,
      homeUrl: 'https://$host/',
      applicationId: 'com.example.demo',
      admobAppId: admobAppId,
      version: '1.0.0+1',
      themeBrightness: 'dark',
      themePrimary: '#16A34A',
      disclaimerEnabled: disclaimerEnabled,
      disclaimerBody: 'Disclaimer body line 1.\nLine 2.',
      adsEnabled: adsEnabled,
      fcmEnabled: false,
      iapEnabled: false,
      fileUploadsEnabled: false,
      scannerEnabled: false,
      splashEnabled: true,
      splashTagline: 'Loading…',
      splashBackgroundColor: '#0B0B0C',
    );
  }

  group('renderWebViewConfigYaml', () {
    test('writes identity into app: block', () {
      final out = renderWebViewConfigYaml(answers(host: 'shop.example.com'));
      expect(out, contains('host: "shop.example.com"'));
      expect(out, contains('application_id: "com.example.demo"'));
      expect(out, contains('home_url: "https://shop.example.com/"'));
    });

    test('comments out admob_app_id when not provided', () {
      final out = renderWebViewConfigYaml(answers());
      expect(out, contains('# admob_app_id:'));
      // No uncommented admob_app_id line. The placeholder comment line
      // contains the substring "admob_app_id: \"ca-app-pub" by design,
      // so we anchor on indentation to ensure no active assignment.
      expect(
        RegExp(r'^  admob_app_id:', multiLine: true).hasMatch(out),
        isFalse,
      );
    });

    test('writes admob_app_id when provided', () {
      final out = renderWebViewConfigYaml(answers(
        admobAppId: 'ca-app-pub-1234567890123456~1234567890',
      ));
      expect(
        out,
        contains('admob_app_id: "ca-app-pub-1234567890123456~1234567890"'),
      );
    });

    test('disclaimer body indents into YAML literal block', () {
      final out = renderWebViewConfigYaml(
        answers(disclaimerEnabled: true),
      );
      expect(out, contains('enabled: true'));
      expect(out, contains('      Disclaimer body line 1.'));
      expect(out, contains('      Line 2.'));
    });

    test('propagates host into navigation/security blocks', () {
      final out = renderWebViewConfigYaml(answers(host: 'shop.example.com'));
      // restrict_to_hosts and deep_links.hosts should both list the host.
      final occurrences = RegExp('shop\\.example\\.com').allMatches(out).length;
      expect(occurrences, greaterThanOrEqualTo(4));
    });

    test('ads.enabled mirrors the answer', () {
      expect(
        renderWebViewConfigYaml(answers()),
        contains('enabled: false'),
      );
      expect(
        renderWebViewConfigYaml(answers(adsEnabled: true)),
        contains('enabled: true'),
      );
    });
  });

  group('patchPubspecForLaunchAssets', () {
    const baseline = 'name: foo\n'
        'version: 1.0.0+1\n'
        'dev_dependencies:\n'
        '  flutter_launcher_icons: ^0.14.1\n'
        '  flutter_native_splash: ^2.4.4\n';

    test('appends launcher block when icon path provided', () {
      final out = patchPubspecForLaunchAssets(
        baseline,
        launcherIconPath: 'assets/launcher/icon.png',
        splashEnabled: false,
        splashBg: '#0B0B0C',
        splashImageAsset: null,
      );
      // Top-level launcher block was appended; no top-level splash block
      // (the indented dev-dep line for flutter_native_splash is NOT a
      // top-level block — that's exactly what the impl's line-anchored
      // regex distinguishes).
      expect(
        RegExp(r'^flutter_launcher_icons:', multiLine: true).hasMatch(out),
        isTrue,
      );
      expect(out, contains('image_path: "assets/launcher/icon.png"'));
      expect(
        RegExp(r'^flutter_native_splash:', multiLine: true).hasMatch(out),
        isFalse,
      );
    });

    test('appends splash block when splash enabled', () {
      final out = patchPubspecForLaunchAssets(
        baseline,
        launcherIconPath: null,
        splashEnabled: true,
        splashBg: '#0B0B0C',
        splashImageAsset: 'assets/splash/logo.png',
      );
      expect(
        RegExp(r'^flutter_native_splash:', multiLine: true).hasMatch(out),
        isTrue,
      );
      expect(out, contains('color: "#0B0B0C"'));
      expect(out, contains('image: assets/splash/logo.png'));
    });

    test('is idempotent — does not duplicate blocks', () {
      var out = patchPubspecForLaunchAssets(
        baseline,
        launcherIconPath: 'assets/launcher/icon.png',
        splashEnabled: true,
        splashBg: '#0B0B0C',
        splashImageAsset: null,
      );
      out = patchPubspecForLaunchAssets(
        out,
        launcherIconPath: 'assets/launcher/icon.png',
        splashEnabled: true,
        splashBg: '#0B0B0C',
        splashImageAsset: null,
      );
      // Count only top-level (line-start) blocks, not dev-dep lines that
      // share the same name. After two patches each top-level block must
      // appear exactly once.
      expect(
        RegExp(r'^flutter_launcher_icons:', multiLine: true)
            .allMatches(out)
            .length,
        1,
      );
      expect(
        RegExp(r'^flutter_native_splash:', multiLine: true)
            .allMatches(out)
            .length,
        1,
      );
    });
  });

  group('renderKeyProperties', () {
    test('renders the four required fields', () {
      final out = renderKeyProperties(
        storePassword: 'p1',
        keyPassword: 'p2',
        keyAlias: 'upload',
        storeFile: '/abs/path/upload-keystore.jks',
      );
      expect(out, contains('storePassword=p1'));
      expect(out, contains('keyPassword=p2'));
      expect(out, contains('keyAlias=upload'));
      expect(out, contains('storeFile=/abs/path/upload-keystore.jks'));
    });
  });
}
