// Tests for tool/doctor_lib.dart. Each pure check is exercised against
// a synthetic project root in `Directory.systemTemp`. The two checks
// that shell out (checkFlutter, checkJavaJdk) are not covered here —
// they are the responsibility of the CI environment, not of this unit
// test, and stubbing Process.run would test the stub, not the logic.

// `tool/` lives outside `lib/`, so this test reaches it via a relative
// import. The `always_use_package_imports` lint is suppressed for that
// reason.
// ignore_for_file: always_use_package_imports

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/doctor_lib.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('websight_doctor_test_');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  void writeFile(String relPath, String body) {
    final f = File('${root.path}/$relPath');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(body);
  }

  group('checkProjectIdentity', () {
    test('fails when YAML is missing', () {
      final r = checkProjectIdentity(root);
      expect(r.status, DoctorStatus.fail);
      expect(r.label, 'identity');
      expect(r.detail, contains('missing'));
    });

    test('warns when YAML is still on the demo flutter.dev host', () {
      writeFile('assets/webview_config.yaml', '''
app:
  name: "WebSight"
  host: "flutter.dev"
  application_id: "com.example.demo"
''');
      final r = checkProjectIdentity(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.detail, contains('demo'));
    });

    test('warns when application_id is unset', () {
      writeFile('assets/webview_config.yaml', '''
app:
  name: "Shop"
  host: "shop.example.com"
''');
      final r = checkProjectIdentity(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.detail, contains('application_id'));
    });

    test('passes when YAML has custom host + applicationId', () {
      writeFile('assets/webview_config.yaml', '''
app:
  name: "Shop"
  host: "shop.example.com"
  application_id: "com.example.shop"
''');
      final r = checkProjectIdentity(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkFirebaseWiring', () {
    test('warns when both files are missing', () {
      final r = checkFirebaseWiring(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.fix, contains('flutterfire configure'));
    });

    test('warns when firebase_options.dart still has placeholders', () {
      writeFile('lib/firebase_options.dart',
          'const apiKey = "YOUR_API_KEY"; // placeholder');
      writeFile('android/app/google-services.json', '{ "project_info": {} }');
      final r = checkFirebaseWiring(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.detail, contains('placeholder'));
    });

    test('passes when both files look real', () {
      writeFile('lib/firebase_options.dart',
          'class DefaultFirebaseOptions { static const android = "abc"; }');
      writeFile('android/app/google-services.json',
          '{ "project_info": { "project_number": "12345" } }');
      final r = checkFirebaseWiring(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkLauncherIcon', () {
    test('warns when assets/launcher/icon.png is missing', () {
      final r = checkLauncherIcon(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.fix, contains('icon.kitchen'));
    });

    test('passes when assets/launcher/icon.png exists', () {
      writeFile('assets/launcher/icon.png', 'fake-png-bytes');
      final r = checkLauncherIcon(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkSplashImage', () {
    test('reports info (not warn) when splash logo is missing — optional', () {
      final r = checkSplashImage(root);
      expect(r.status, DoctorStatus.info);
    });

    test('passes when splash logo is present', () {
      writeFile('assets/splash/logo.png', 'fake-png-bytes');
      final r = checkSplashImage(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkSigning', () {
    test('reports info when key.properties is missing', () {
      final r = checkSigning(root);
      expect(r.status, DoctorStatus.info);
      expect(r.detail, contains('debug signing'));
    });

    test('passes when key.properties exists', () {
      writeFile('android/key.properties', 'storePassword=...\nkeyAlias=upload');
      final r = checkSigning(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkAdMobAppId', () {
    test('warns when manifest still has the AdMob test App ID', () {
      writeFile('android/app/src/main/AndroidManifest.xml', '''
<manifest>
  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
             android:value="ca-app-pub-3940256099942544~3347511713" />
</manifest>
''');
      final r = checkAdMobAppId(root);
      expect(r.status, DoctorStatus.warn);
      expect(r.detail, contains('test'));
    });

    test('passes when manifest carries a non-test App ID', () {
      writeFile('android/app/src/main/AndroidManifest.xml', '''
<manifest>
  <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
             android:value="ca-app-pub-1234567890123456~1234567890" />
</manifest>
''');
      final r = checkAdMobAppId(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkDeepLinkHostMatchesYaml', () {
    test('fails when manifest host does not match YAML host', () {
      writeFile('assets/webview_config.yaml', '''
app:
  name: "Shop"
  host: "shop.example.com"
''');
      writeFile('android/app/src/main/AndroidManifest.xml', '''
<intent-filter android:autoVerify="true">
    <data android:host="OLD_HOST" />
</intent-filter>
''');
      final r = checkDeepLinkHostMatchesYaml(root);
      expect(r.status, DoctorStatus.fail);
      expect(r.fix, contains('configure.dart'));
    });

    test('passes when hosts match', () {
      writeFile('assets/webview_config.yaml', '''
app:
  name: "Shop"
  host: "shop.example.com"
''');
      writeFile('android/app/src/main/AndroidManifest.xml',
          '<data android:host="shop.example.com" />');
      final r = checkDeepLinkHostMatchesYaml(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('checkTemplatePlaceholders', () {
    test('warns when manifest still has YOUR_PRIMARY_HOST', () {
      writeFile('android/app/src/main/AndroidManifest.xml',
          '<data android:host="YOUR_PRIMARY_HOST" />');
      final r = checkTemplatePlaceholders(root);
      expect(r.status, DoctorStatus.warn);
    });

    test('passes when no placeholders remain', () {
      writeFile('android/app/src/main/AndroidManifest.xml',
          '<data android:host="real-host.example.com" />');
      final r = checkTemplatePlaceholders(root);
      expect(r.status, DoctorStatus.ok);
    });
  });

  group('DoctorResult', () {
    test('isHardFail is true only for fail status', () {
      DoctorResult mk(DoctorStatus s) =>
          DoctorResult(status: s, label: 'x', detail: 'y');
      expect(mk(DoctorStatus.ok).isHardFail, isFalse);
      expect(mk(DoctorStatus.warn).isHardFail, isFalse);
      expect(mk(DoctorStatus.info).isHardFail, isFalse);
      expect(mk(DoctorStatus.fail).isHardFail, isTrue);
    });
  });
}
