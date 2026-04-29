// `tool/` lives outside `lib/`, so this test reaches it via a relative
// import. The `always_use_package_imports` lint is suppressed for that
// reason.
// ignore_for_file: always_use_package_imports

// Unit tests for the substitution logic in tool/configure_lib.dart.
//
// We test the pure transform functions directly against representative
// snippets of the real production files. Keeping the input fixtures small
// and focused means a regex change that works for the snippet but not for
// the live file is a code-review concern, not a test concern — that
// trade-off is intentional. End-to-end behaviour is covered by the
// `flutter build apk --debug` step in CI after configure runs on the
// fixture repo.

import 'package:flutter_test/flutter_test.dart';

import '../../tool/configure_lib.dart';

void main() {
  AppIdentity sample({
    String? applicationId = 'com.example.shop',
    String? admobAppId = 'ca-app-pub-1234567890123456~1234567890',
    String? version,
    String name = 'My Shop',
    String host = 'shop.example.com',
  }) =>
      AppIdentity(
        name: name,
        host: host,
        applicationId: applicationId,
        admobAppId: admobAppId,
        version: version,
      );

  group('AppIdentity.fromYamlString', () {
    test('reads required and optional keys from a wrapped YAML', () {
      final id = AppIdentity.fromYamlString('''
webview_config:
  app:
    name: "Shop"
    host: "shop.example.com"
    home_url: "https://shop.example.com/"
    application_id: "com.example.shop"
    admob_app_id: "ca-app-pub-1~2"
    version: "1.2.3+4"
''');
      expect(id.name, 'Shop');
      expect(id.host, 'shop.example.com');
      expect(id.applicationId, 'com.example.shop');
      expect(id.admobAppId, 'ca-app-pub-1~2');
      expect(id.version, '1.2.3+4');
    });

    test('reads identity from an unwrapped YAML', () {
      final id = AppIdentity.fromYamlString('''
app:
  name: "Demo"
  host: "demo.example.com"
''');
      expect(id.host, 'demo.example.com');
      expect(id.applicationId, isNull);
      expect(id.version, isNull);
    });

    test('throws when the app: block is missing', () {
      expect(
        () => AppIdentity.fromYamlString(
            'flutter_ui:\n  theme: { brightness: dark }\n'),
        throwsA(isA<ConfigureError>()),
      );
    });
  });

  group('AppIdentity.validate', () {
    test('passes for well-formed values', () {
      sample().validate(); // no throw
    });

    test('rejects URL-like host', () {
      expect(
        () => sample(applicationId: null, admobAppId: null)..validate(),
        returnsNormally,
      );
      expect(
        () => AppIdentity(
          name: 'x',
          host: 'https://shop.example.com',
          applicationId: null,
          admobAppId: null,
          version: null,
        ).validate(),
        throwsA(isA<ConfigureError>()),
      );
    });

    test('rejects malformed application id', () {
      expect(
        () => sample(applicationId: 'NotReverseDns').validate(),
        throwsA(isA<ConfigureError>()),
      );
    });

    test('rejects AdMob unit-id-shaped value (slash, not tilde)', () {
      expect(
        () => sample(admobAppId: 'ca-app-pub-1234567890/1234567890').validate(),
        throwsA(isA<ConfigureError>()),
      );
    });
  });

  group('gradleOp', () {
    const before = '''
android {
    namespace = "com.app.websight"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.app.websight"
        minSdk = 24
    }
}
''';

    test('rewrites both applicationId and namespace', () {
      final out = gradleOp(sample()).transform(before);
      expect(out, contains('applicationId = "com.example.shop"'));
      expect(out, contains('namespace = "com.example.shop"'));
      expect(out, isNot(contains('com.app.websight')));
    });

    test('is idempotent', () {
      final once = gradleOp(sample()).transform(before);
      final twice = gradleOp(sample()).transform(once);
      expect(twice, once);
    });

    test('leaves file unchanged when application_id unset', () {
      final out = gradleOp(sample(applicationId: null)).transform(before);
      expect(out, before);
    });

    test('does not clobber productFlavor applicationIds', () {
      const flavored = '''
android {
    namespace = "com.app.websight"

    defaultConfig {
        applicationId = "com.app.websight"
        minSdk = 24
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("play") {
            dimension = "distribution"
            applicationIdSuffix = ".play"
        }
        create("foss") {
            dimension = "distribution"
            applicationId = "com.app.websight.foss"
        }
    }
}
''';
      final out = gradleOp(sample()).transform(flavored);
      // defaultConfig got rewritten…
      expect(
          out,
          contains(
              'defaultConfig {\n        applicationId = "com.example.shop"'));
      // …but the foss flavor's explicit applicationId is preserved.
      expect(out, contains('applicationId = "com.app.websight.foss"'));
      // …and applicationIdSuffix is not collapsed into applicationId.
      expect(out, contains('applicationIdSuffix = ".play"'));
    });
  });

  group('manifestOp', () {
    const before = '''
<intent-filter android:autoVerify="true">
    <data android:scheme="https" />
    <data android:host="YOUR_PRIMARY_HOST" />
</intent-filter>

<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713" />
''';

    test('rewrites deep-link host and AdMob value', () {
      final out = manifestOp(sample()).transform(before);
      expect(out, contains('android:host="shop.example.com"'));
      expect(out,
          contains('android:value="ca-app-pub-1234567890123456~1234567890"'));
    });

    test('rewrites deep-link host even when admob unset', () {
      final out = manifestOp(sample(admobAppId: null)).transform(before);
      expect(out, contains('android:host="shop.example.com"'));
      // AdMob block stays put when admob_app_id is unset.
      expect(out, contains('ca-app-pub-3940256099942544~3347511713'));
    });

    test('does not touch the FCM channel meta-data adjacent to AdMob', () {
      const before = '''
<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="websight_default_channel" />
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713" />
''';
      final out = manifestOp(sample()).transform(before);
      expect(out, contains('android:value="websight_default_channel"'));
      expect(out, contains('ca-app-pub-1234567890123456~1234567890'));
    });

    test('only rewrites host inside the autoVerify intent-filter', () {
      const before = '''
<intent-filter android:autoVerify="true">
    <data android:scheme="https" />
    <data android:host="YOUR_PRIMARY_HOST" />
</intent-filter>

<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="myappoauth" />
    <data android:host="oauth.callback.example.com" />
</intent-filter>
''';
      final out = manifestOp(sample()).transform(before);
      expect(out, contains('android:host="shop.example.com"'));
      // The non-autoVerify intent-filter's host is preserved.
      expect(out, contains('android:host="oauth.callback.example.com"'));
    });
  });

  group('stringsOp', () {
    test('rewrites app_name and XML-escapes special chars', () {
      const before = '<resources>\n'
          '    <string name="app_name">WebSight</string>\n'
          '</resources>\n';
      final out = stringsOp(sample(name: 'Shop & Co.')).transform(before);
      expect(out, contains('<string name="app_name">Shop &amp; Co.</string>'));
    });
  });

  group('pubspecOp', () {
    const before = '''
name: websight
description: foo
publish_to: 'none'
version: 1.0.0+1
''';

    test('snake-cases display name and rewrites version when provided', () {
      final out = pubspecOp(sample(version: '2.0.0+5')).transform(before);
      expect(out, contains('name: my_shop'));
      expect(out, contains('version: 2.0.0+5'));
    });

    test('omitting version leaves the pubspec version line alone', () {
      final out = pubspecOp(sample()).transform(before);
      expect(out, contains('version: 1.0.0+1'));
    });

    test('strips characters that are illegal in a pubspec name', () {
      expect(pubspecName('My-Shop! 2.0'), 'my_shop_2_0');
      expect(pubspecName('   '), 'websight');
    });
  });

  group('yamlHostsOp', () {
    test('propagates app.host into restrict_to_hosts and deep_links.hosts', () {
      const before = '''
navigation:
  external_allowlist: []
  deep_links:
    enable: true
    hosts:
      - "old.example.com"

security:
  restrict_to_hosts:
    - "old.example.com"
''';
      final out =
          yamlHostsOp(sample(), 'webview_config.yaml').transform(before);
      expect(out, contains('- "shop.example.com"'));
      expect(out, isNot(contains('old.example.com')));
    });

    test('preserves additional host entries (replaces only the first)', () {
      const before = '''
navigation:
  deep_links:
    enable: true
    hosts:
      - "old.example.com"
      - "cdn.example.com"

security:
  restrict_to_hosts:
    - "old.example.com"
    - "login.example.com"
''';
      final out =
          yamlHostsOp(sample(), 'webview_config.yaml').transform(before);
      expect(out, contains('- "shop.example.com"'));
      expect(out, contains('- "cdn.example.com"'));
      expect(out, contains('- "login.example.com"'));
    });
  });

  group('auditYamlHostMultiplicity', () {
    test('counts entries under restrict_to_hosts and deep_links.hosts', () {
      const yaml = '''
navigation:
  deep_links:
    enable: true
    hosts:
      - "a.example.com"
      - "b.example.com"

security:
  restrict_to_hosts:
    - "a.example.com"
''';
      final audit = auditYamlHostMultiplicity(yaml);
      expect(audit.restrictHosts, 1);
      expect(audit.deepLinkHosts, 2);
      expect(audit.hasExtraEntries, isTrue);
    });

    test('returns false for hasExtraEntries on a single-host config', () {
      const yaml = '''
navigation:
  deep_links:
    enable: true
    hosts:
      - "only.example.com"

security:
  restrict_to_hosts:
    - "only.example.com"
''';
      final audit = auditYamlHostMultiplicity(yaml);
      expect(audit.restrictHosts, 1);
      expect(audit.deepLinkHosts, 1);
      expect(audit.hasExtraEntries, isFalse);
    });

    test('handles missing keys gracefully', () {
      const yaml = '''
flutter_ui:
  theme: { brightness: dark }
''';
      final audit = auditYamlHostMultiplicity(yaml);
      expect(audit.restrictHosts, 0);
      expect(audit.deepLinkHosts, 0);
      expect(audit.hasExtraEntries, isFalse);
    });
  });

  group('xmlEscape', () {
    test('escapes the XML metacharacters', () {
      expect(xmlEscape('A & B <c> "d"'), 'A &amp; B &lt;c&gt; "d"');
    });
  });
}
