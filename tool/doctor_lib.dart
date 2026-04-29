// Pure diagnostic logic for `tool/doctor.dart`. Each check returns a
// [DoctorResult] describing one fact about the project / toolchain. The
// CLI just renders them.

// ignore_for_file: always_use_package_imports

import 'dart:io';

enum DoctorStatus { ok, warn, fail, info }

class DoctorResult {
  DoctorResult({
    required this.status,
    required this.label,
    required this.detail,
    this.fix,
  });

  final DoctorStatus status;
  final String label;
  final String detail;

  /// Optional one-liner the user can run to address the issue.
  final String? fix;

  bool get isHardFail => status == DoctorStatus.fail;
}

/// Top-level: runs every check and returns the list. Pure-async so the
/// CLI can render a spinner per check.
Future<List<DoctorResult>> runAllChecks(Directory root) async {
  return [
    await checkFlutter(),
    await checkJavaJdk(),
    checkProjectIdentity(root),
    checkFirebaseWiring(root),
    checkLauncherIcon(root),
    checkSplashImage(root),
    checkSigning(root),
    checkAdMobAppId(root),
    checkDeepLinkHostMatchesYaml(root),
    checkTemplatePlaceholders(root),
  ];
}

Future<DoctorResult> checkFlutter() async {
  try {
    final r = await Process.run('flutter', ['--version'], runInShell: true);
    if (r.exitCode != 0) {
      return DoctorResult(
        status: DoctorStatus.fail,
        label: 'flutter',
        detail: 'flutter --version exited with ${r.exitCode}',
        fix:
            'Install Flutter stable: https://docs.flutter.dev/get-started/install',
      );
    }
    final firstLine =
        r.stdout.toString().split('\n').firstWhere((l) => l.trim().isNotEmpty);
    return DoctorResult(
      status: DoctorStatus.ok,
      label: 'flutter',
      detail: firstLine.trim(),
    );
  } catch (_) {
    return DoctorResult(
      status: DoctorStatus.fail,
      label: 'flutter',
      detail: 'flutter binary not found on PATH',
      fix: 'Install Flutter stable and ensure `flutter` is on your PATH.',
    );
  }
}

Future<DoctorResult> checkJavaJdk() async {
  try {
    final r = await Process.run('java', ['-version'], runInShell: true);
    final out = (r.stderr.toString() + r.stdout.toString()).trim();
    final m = RegExp(r'version "(\d+)').firstMatch(out);
    if (m == null) {
      return DoctorResult(
        status: DoctorStatus.warn,
        label: 'jdk',
        detail: 'Could not parse Java version from `java -version`.',
      );
    }
    final major = int.parse(m.group(1)!);
    if (major < 17) {
      return DoctorResult(
        status: DoctorStatus.fail,
        label: 'jdk',
        detail: 'JDK $major detected; AGP 8.x requires JDK 17+',
        fix: 'Install JDK 17 (Temurin / Microsoft / Zulu).',
      );
    }
    return DoctorResult(
      status: DoctorStatus.ok,
      label: 'jdk',
      detail: 'JDK $major',
    );
  } catch (_) {
    return DoctorResult(
      status: DoctorStatus.fail,
      label: 'jdk',
      detail: 'java binary not found on PATH',
      fix: 'Install JDK 17 and ensure `java` is on your PATH.',
    );
  }
}

DoctorResult checkProjectIdentity(Directory root) {
  final yaml = File('${root.path}/assets/webview_config.yaml');
  if (!yaml.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.fail,
      label: 'identity',
      detail: 'assets/webview_config.yaml is missing',
      fix: 'Run `dart run tool/init.dart` to create one.',
    );
  }
  final body = yaml.readAsStringSync();
  final isDemo = body.contains('host: "flutter.dev"') ||
      body.contains('YOUR_PRIMARY_HOST_HERE');
  if (isDemo) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'identity',
      detail: 'YAML is still on the demo template host (flutter.dev).',
      fix: 'Run `dart run tool/init.dart` to set your own identity.',
    );
  }
  if (!body.contains('application_id:')) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'identity',
      detail: 'app.application_id not set; AAB will use the default '
          '"com.app.websight" applicationId.',
      fix: 'Add app.application_id to YAML and re-run '
          '`dart run tool/configure.dart`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'identity',
    detail: 'YAML configured with custom host + applicationId.',
  );
}

DoctorResult checkFirebaseWiring(Directory root) {
  final fb = File('${root.path}/lib/firebase_options.dart');
  final gs = File('${root.path}/android/app/google-services.json');
  if (!fb.existsSync() || !gs.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'firebase',
      detail: 'Firebase config files missing.',
      fix: 'Run `flutterfire configure` to wire your project.',
    );
  }
  final fbBody = fb.readAsStringSync();
  if (fbBody.contains('YOUR_API_KEY') || fbBody.contains('YOUR_APP_ID')) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'firebase',
      detail: 'firebase_options.dart still has placeholder values.',
      fix: 'Run `flutterfire configure` to replace them.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'firebase',
    detail: 'firebase_options.dart + google-services.json look real.',
  );
}

DoctorResult checkLauncherIcon(Directory root) {
  final f = File('${root.path}/assets/launcher/icon.png');
  if (!f.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'launcher icon',
      detail: 'assets/launcher/icon.png missing.',
      fix:
          'Generate one at https://icon.kitchen/, drop it at assets/launcher/icon.png, '
          'then run `dart run flutter_launcher_icons`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'launcher icon',
    detail: 'assets/launcher/icon.png present.',
  );
}

DoctorResult checkSplashImage(Directory root) {
  final f = File('${root.path}/assets/splash/logo.png');
  if (!f.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.info,
      label: 'splash image',
      detail: 'assets/splash/logo.png missing (optional).',
      fix: 'Drop one and run `dart run flutter_native_splash:create`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'splash image',
    detail: 'assets/splash/logo.png present.',
  );
}

DoctorResult checkSigning(Directory root) {
  final f = File('${root.path}/android/key.properties');
  if (!f.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.info,
      label: 'signing',
      detail:
          'android/key.properties missing. Release builds will fall back to debug signing.',
      fix: 'Run `dart run tool/init.dart` and accept the keystore step, '
          'or `keytool -genkey` manually.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'signing',
    detail: 'android/key.properties present.',
  );
}

DoctorResult checkAdMobAppId(Directory root) {
  final manifest =
      File('${root.path}/android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.fail,
      label: 'admob',
      detail: 'AndroidManifest.xml missing.',
    );
  }
  final body = manifest.readAsStringSync();
  if (body.contains('ca-app-pub-3940256099942544~3347511713')) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'admob',
      detail:
          'Manifest has Google\'s test AdMob App ID. Replace before publishing.',
      fix:
          'Set app.admob_app_id in YAML and re-run `dart run tool/configure.dart`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'admob',
    detail: 'AdMob App ID is non-test.',
  );
}

DoctorResult checkDeepLinkHostMatchesYaml(Directory root) {
  final yaml = File('${root.path}/assets/webview_config.yaml');
  final manifest =
      File('${root.path}/android/app/src/main/AndroidManifest.xml');
  if (!yaml.existsSync() || !manifest.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'deep-link host',
      detail: 'Cannot check (yaml or manifest missing).',
    );
  }
  final hostMatch =
      RegExp(r'^\s+host:\s*"([^"]+)"', multiLine: true).firstMatch(
    yaml.readAsStringSync(),
  );
  final host = hostMatch?.group(1);
  // `flutter.dev` is the demo template's home URL; an unmodified
  // checkout is expected to have it in YAML but NOT in the manifest
  // (the manifest still carries the YOUR_PRIMARY_HOST placeholder
  // until `dart run tool/configure.dart` runs). Treat it as a
  // placeholder so the doctor can run cleanly in CI on a fresh fork.
  const demoHosts = {
    'YOUR_PRIMARY_HOST_HERE',
    'flutter.dev',
  };
  if (host == null || demoHosts.contains(host)) {
    return DoctorResult(
      status: DoctorStatus.info,
      label: 'deep-link host',
      detail: 'app.host is unset / template placeholder.',
    );
  }
  if (!manifest.readAsStringSync().contains('android:host="$host"')) {
    return DoctorResult(
      status: DoctorStatus.fail,
      label: 'deep-link host',
      detail:
          'Manifest <data android:host> does not match YAML app.host="$host".',
      fix: 'Run `dart run tool/configure.dart`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'deep-link host',
    detail: 'Manifest host matches YAML ($host).',
  );
}

DoctorResult checkTemplatePlaceholders(Directory root) {
  final manifest =
      File('${root.path}/android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'placeholders',
      detail: 'Manifest missing.',
    );
  }
  final body = manifest.readAsStringSync();
  if (body.contains('YOUR_PRIMARY_HOST') ||
      body.contains('YOUR_FIREBASE_API_KEY')) {
    return DoctorResult(
      status: DoctorStatus.warn,
      label: 'placeholders',
      detail: 'Template placeholders still present in manifest.',
      fix: 'Run `dart run tool/init.dart` or `dart run tool/configure.dart`.',
    );
  }
  return DoctorResult(
    status: DoctorStatus.ok,
    label: 'placeholders',
    detail: 'No placeholder strings in manifest.',
  );
}
