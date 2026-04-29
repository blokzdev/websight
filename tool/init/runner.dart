// Wizard step orchestration. Reads from a [Prompter], writes the YAML,
// runs subprocess steps (configure, change_app_package_name, icons,
// splash, flutterfire, keytool, smoke build). Resumable: every step
// checks state before acting.

// ignore_for_file: always_use_package_imports

import 'dart:io';

import '../configure_lib.dart';
import '../init_lib.dart';
import 'prompter.dart';

class WizardOptions {
  WizardOptions({
    required this.projectRoot,
    required this.skipPubGet,
    required this.skipFirebase,
    required this.skipKeystore,
    required this.skipSmoke,
  });

  final Directory projectRoot;
  final bool skipPubGet;
  final bool skipFirebase;
  final bool skipKeystore;
  final bool skipSmoke;
}

Future<int> runWizard(Prompter p, WizardOptions opts) async {
  final state = ProjectState.detect(opts.projectRoot);

  // ---------- Welcome ----------
  p.section('WebSight init');
  p.info('Walks you through identity, theme, splash, services, and signing.');
  p.info('Re-runnable: every step is idempotent; existing state is preserved.');
  if (state.hasIdentityConfigured) {
    p.warn(
      'It looks like assets/webview_config.yaml is already customized '
      '(host != demo). Continuing will overwrite it; the previous file '
      'will be backed up to .bak.',
    );
    if (!p.confirm('Continue?', defaultValue: false)) return 0;
  }

  // ---------- Identity ----------
  p.section('Identity');
  final answers = _collectAnswers(p);

  // ---------- Confirm summary ----------
  p.section('Summary');
  _printSummary(p, answers);
  if (!p.confirm('Write this configuration?', defaultValue: true)) {
    p.info('Aborted.');
    return 0;
  }

  // Subprocess steps run sequentially after this point and any of them
  // can fail (configure, change_app_package_name, launcher icons,
  // splash, flutterfire, keytool). On failure we emit one clean line
  // identifying the step + tail of stderr instead of letting a Dart
  // stack trace dump on the user.
  try {
    // ---------- Write YAML + propagate ----------
    await _writeYamlAndPropagate(p, opts.projectRoot, answers);

    // ---------- Optional Kotlin package rename ----------
    await _maybeRenamePackage(p, answers);

    // ---------- Icons ----------
    await _maybeRunLauncherIcons(p, opts.projectRoot, answers);

    // ---------- Splash ----------
    await _maybeRunNativeSplash(p, opts.projectRoot, answers);

    // ---------- Firebase ----------
    await _maybeRunFlutterfire(p, opts);

    // ---------- Keystore ----------
    await _maybeGenerateKeystore(p, opts);

    // ---------- Smoke ----------
    await _maybeRunSmoke(p, opts);
  } on _SubprocessFailure catch (e) {
    p.error('Wizard halted: $e');
    p.info('Re-run `dart run tool/init.dart` once the failing step '
        'is fixed. Steps that already succeeded are idempotent.');
    return 1;
  }

  // ---------- Final checklist ----------
  _printFinalChecklist(p, answers);
  return 0;
}

WizardAnswers _collectAnswers(Prompter p) {
  final name = p.text(
    'App display name',
    defaultValue: 'WebSight',
    validator: (s) => s.trim().isEmpty ? 'name cannot be empty' : null,
  );
  final host = p.text(
    'Primary host (no scheme, no path)',
    defaultValue: 'flutter.dev',
    validator: validateHost,
  );
  final homeUrl = p.text(
    'Home URL',
    defaultValue: 'https://$host/',
    validator: (s) => validateHomeUrl(s, host: host),
  );
  final applicationId = p.text(
    'Android applicationId (reverse-DNS)',
    defaultValue: 'com.yourcompany.${_slug(name)}',
    validator: validateApplicationId,
  );
  final admobAppId = p.text(
    'AdMob App ID (leave empty to skip ads for now)',
    defaultValue: '',
    validator: validateAdmobAppId,
  );
  final version = p.text(
    'Version',
    defaultValue: '1.0.0+1',
    validator: validateVersion,
  );

  // Theme
  final brightness = p.chooseOne(
    'Theme brightness',
    ['dark', 'light', 'system'],
    defaultValue: 'dark',
  );
  final primary = p.text(
    'Theme primary color (hex)',
    defaultValue: '#16A34A',
    validator: validateHexColor,
  );

  // Disclaimer
  final defaultsToOn = looksThirdParty(host);
  final disclaimerEnabled = p.confirm(
    'Wrapping a third-party site? Enable the unofficial-app disclaimer dialog?',
    defaultValue: defaultsToOn,
  );
  final disclaimerBody =
      disclaimerEnabled ? defaultDisclaimerBody(host: host, name: name) : '';

  // Features
  final adsEnabled = admobAppId.isNotEmpty &&
      p.confirm('Enable AdMob banner ads now?', defaultValue: false);
  final fcmEnabled =
      p.confirm('Enable Firebase Cloud Messaging (push)?', defaultValue: false);
  final iapEnabled = p.confirm('Enable in-app purchases?', defaultValue: false);
  final fileUploadsEnabled = p.confirm(
    'Enable file uploads from <input type=file>?',
    defaultValue: false,
  );
  final scannerEnabled = p.confirm(
    'Enable barcode scanner (camera permission)?',
    defaultValue: false,
  );

  // Splash
  final splashEnabled = p.confirm(
    'Enable in-Flutter splash overlay?',
    defaultValue: true,
  );
  final splashBg = splashEnabled
      ? p.text(
          'Splash background color (hex)',
          defaultValue: '#0B0B0C',
          validator: validateHexColor,
        )
      : '#0B0B0C';
  final splashTagline = splashEnabled
      ? p.text('Splash tagline (optional, blank to skip)', defaultValue: '')
      : '';

  return WizardAnswers(
    name: name,
    host: host,
    homeUrl: homeUrl,
    applicationId: applicationId,
    admobAppId: admobAppId.isEmpty ? null : admobAppId,
    version: version,
    themeBrightness: brightness,
    themePrimary: primary,
    disclaimerEnabled: disclaimerEnabled,
    disclaimerBody: disclaimerBody,
    adsEnabled: adsEnabled,
    fcmEnabled: fcmEnabled,
    iapEnabled: iapEnabled,
    fileUploadsEnabled: fileUploadsEnabled,
    scannerEnabled: scannerEnabled,
    splashEnabled: splashEnabled,
    splashTagline: splashTagline,
    splashBackgroundColor: splashBg,
  );
}

void _printSummary(Prompter p, WizardAnswers a) {
  p.info('  name              ${a.name}');
  p.info('  host              ${a.host}');
  p.info('  home_url          ${a.homeUrl}');
  p.info('  application_id    ${a.applicationId}');
  p.info('  admob_app_id      ${a.admobAppId ?? "(skipped — ads disabled)"}');
  p.info('  version           ${a.version}');
  p.info('  theme             ${a.themeBrightness} / ${a.themePrimary}');
  p.info('  disclaimer        ${a.disclaimerEnabled ? "ON" : "off"}');
  p.info('  ads               ${a.adsEnabled ? "ON" : "off"}');
  p.info('  fcm               ${a.fcmEnabled ? "ON" : "off"}');
  p.info('  iap               ${a.iapEnabled ? "ON" : "off"}');
  p.info('  file_uploads      ${a.fileUploadsEnabled ? "ON" : "off"}');
  p.info('  splash            '
      '${a.splashEnabled ? "ON, bg ${a.splashBackgroundColor}" : "off"}');
}

Future<void> _writeYamlAndPropagate(
  Prompter p,
  Directory root,
  WizardAnswers a,
) async {
  final yaml = File('${root.path}/assets/webview_config.yaml');
  if (yaml.existsSync()) {
    final bak = File('${yaml.path}.bak');
    bak.writeAsStringSync(yaml.readAsStringSync());
    p.info('Backed up previous config to ${bak.path}');
  }
  yaml.writeAsStringSync(renderWebViewConfigYaml(a));
  p.success('Wrote ${yaml.path}');

  await p
      .progress('Propagating identity to gradle / manifest / strings / pubspec',
          () async {
    final identity = wizardAnswersToIdentity(a);
    identity.validate();
    final ops = <Op>[
      gradleOp(identity),
      manifestOp(identity),
      stringsOp(identity),
      pubspecOp(identity),
    ];
    for (final op in ops) {
      final f = File('${root.path}/${op.path}');
      if (!f.existsSync()) continue;
      f.writeAsStringSync(op.transform(f.readAsStringSync()));
    }
    // Patch pubspec for launcher / splash blocks if needed.
    final pubspec = File('${root.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final patched = patchPubspecForLaunchAssets(
        pubspec.readAsStringSync(),
        launcherIconPath:
            File('${root.path}/assets/launcher/icon.png').existsSync()
                ? 'assets/launcher/icon.png'
                : null,
        splashEnabled: a.splashEnabled,
        splashBg: a.splashBackgroundColor,
        splashImageAsset:
            File('${root.path}/assets/splash/logo.png').existsSync()
                ? 'assets/splash/logo.png'
                : null,
      );
      pubspec.writeAsStringSync(patched);
    }
  });
}

Future<void> _maybeRenamePackage(Prompter p, WizardAnswers a) async {
  p.section('Kotlin package rename');
  p.info(
    'Optional: move android/app/src/main/kotlin/com/... to match your '
    'applicationId.',
  );
  p.info(
    'Order note: this tool overwrites build.gradle.kts, so we re-run '
    'tool/configure.dart afterwards.',
  );
  if (!p.confirm('Run change_app_package_name now?', defaultValue: false)) {
    return;
  }
  await p.progress('Renaming Kotlin package', () async {
    final r = await Process.run(
      'dart',
      ['run', 'change_app_package_name:main', a.applicationId],
      runInShell: true,
    );
    if (r.exitCode != 0) {
      throw _SubprocessFailure('change_app_package_name', r);
    }
  });
  await p.progress('Re-propagating identity (configure)', () async {
    final r = await Process.run(
      'dart',
      ['run', 'tool/configure.dart'],
      runInShell: true,
    );
    if (r.exitCode != 0) throw _SubprocessFailure('tool/configure.dart', r);
  });
}

Future<void> _maybeRunLauncherIcons(
  Prompter p,
  Directory root,
  WizardAnswers a,
) async {
  p.section('Launcher icon');
  final iconFile = File('${root.path}/assets/launcher/icon.png');
  if (!iconFile.existsSync()) {
    p.warn('No icon found at assets/launcher/icon.png.');
    p.info(
      'Generate one at https://icon.kitchen/ '
      '(1024x1024 PNG, transparent background works best),',
    );
    p.info('drop it at assets/launcher/icon.png, then re-run this wizard.');
    return;
  }
  if (!p.confirm('Run flutter_launcher_icons now?', defaultValue: true)) {
    return;
  }
  await p.progress('Generating Android launcher icons', () async {
    final r = await Process.run(
      'dart',
      ['run', 'flutter_launcher_icons'],
      runInShell: true,
    );
    if (r.exitCode != 0) throw _SubprocessFailure('flutter_launcher_icons', r);
  });
}

Future<void> _maybeRunNativeSplash(
  Prompter p,
  Directory root,
  WizardAnswers a,
) async {
  if (!a.splashEnabled) return;
  p.section('Native splash');
  if (!p.confirm('Regenerate native splash assets now?', defaultValue: true)) {
    return;
  }
  await p.progress('Generating native splash drawables', () async {
    final r = await Process.run(
      'dart',
      ['run', 'flutter_native_splash:create'],
      runInShell: true,
    );
    if (r.exitCode != 0) {
      throw _SubprocessFailure('flutter_native_splash:create', r);
    }
  });
}

Future<void> _maybeRunFlutterfire(Prompter p, WizardOptions opts) async {
  if (opts.skipFirebase) return;
  p.section('Firebase');
  p.info(
    'Wires google-services.json + lib/firebase_options.dart by talking to '
    'the Firebase CLI. Requires you to be signed in via `firebase login`.',
  );
  if (!p.confirm('Run flutterfire configure now?', defaultValue: true)) {
    p.info('Skipped. Run `flutterfire configure` whenever you are ready.');
    return;
  }
  // Run interactively (inherit stdio) so the user can authenticate.
  final process = await Process.start(
    'flutterfire',
    ['configure'],
    mode: ProcessStartMode.inheritStdio,
    runInShell: true,
  );
  final code = await process.exitCode;
  if (code != 0) {
    // Don't bury this in a `warn()` — Firebase wiring is required for
    // release builds and silently continuing leaves the user with a
    // half-applied configuration.
    throw _SubprocessFailure(
      'flutterfire configure',
      ProcessResult(
          0,
          code,
          '',
          'flutterfire configure exited with code '
              '$code (interactive run; see output above for details)'),
    );
  }
}

Future<void> _maybeGenerateKeystore(Prompter p, WizardOptions opts) async {
  if (opts.skipKeystore) return;
  p.section('Upload keystore');
  final existing = File('${opts.projectRoot.path}/android/key.properties');
  if (existing.existsSync()) {
    p.info('android/key.properties already exists — skipping.');
    return;
  }
  if (!p.confirm(
    'Generate an upload keystore now? (You can do this later.)',
    defaultValue: false,
  )) {
    return;
  }
  final storeFile = p.text(
    'Where to put the keystore (absolute path)',
    defaultValue: '${opts.projectRoot.path}/android/app/upload-keystore.jks',
  );
  final alias = p.text('Key alias', defaultValue: 'upload');
  final storePassword = p.password('Keystore password (min 6 chars)');
  final keyPassword = p.password('Key password (often same as keystore)');

  await p.progress('Running keytool', () async {
    final r = await Process.run(
      'keytool',
      [
        '-genkey',
        '-v',
        '-keystore',
        storeFile,
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-validity',
        '10000',
        '-alias',
        alias,
        '-storepass',
        storePassword,
        '-keypass',
        keyPassword,
        '-dname',
        'CN=Android Debug,O=Android,C=US',
      ],
      runInShell: true,
    );
    if (r.exitCode != 0) throw _SubprocessFailure('keytool', r);
  });

  existing.writeAsStringSync(renderKeyProperties(
    storePassword: storePassword,
    keyPassword: keyPassword,
    keyAlias: alias,
    storeFile: storeFile,
  ));
  p.success('Wrote android/key.properties');
  p.warn('android/key.properties is gitignored. DO NOT commit it.');
}

Future<void> _maybeRunSmoke(Prompter p, WizardOptions opts) async {
  if (opts.skipSmoke) return;
  p.section('Smoke checks');
  if (!opts.skipPubGet) {
    if (p.confirm('Run flutter pub get?', defaultValue: true)) {
      await p.progress('flutter pub get', () async {
        final r =
            await Process.run('flutter', ['pub', 'get'], runInShell: true);
        if (r.exitCode != 0) throw _SubprocessFailure('flutter pub get', r);
      });
    }
  }
  if (p.confirm('Run flutter analyze?', defaultValue: true)) {
    final r = await Process.run('flutter', ['analyze'], runInShell: true);
    if (r.exitCode != 0) {
      p.warn('flutter analyze reported issues:');
      stdout.write(r.stdout);
      stderr.write(r.stderr);
    } else {
      p.success('flutter analyze: clean');
    }
  }
  if (p.confirm('Run flutter test?', defaultValue: true)) {
    final r = await Process.run('flutter', ['test'], runInShell: true);
    if (r.exitCode != 0) {
      p.warn('flutter test reported failures:');
      stdout.write(r.stdout);
      stderr.write(r.stderr);
    } else {
      p.success('flutter test: passing');
    }
  }
}

void _printFinalChecklist(Prompter p, WizardAnswers a) {
  p.section('What is left for you');
  final items = <String>[
    if (!File('assets/launcher/icon.png').existsSync())
      'Drop a launcher icon at assets/launcher/icon.png and re-run the wizard '
          '(or `dart run flutter_launcher_icons`).',
    if (a.adsEnabled)
      'Open https://apps.admob.com, create a banner Ad Unit, paste it into '
          'ads.placements.global_banner.ad_unit_id, then re-run '
          '`dart run tool/configure.dart`.',
    'Trademark / ToS review for ${a.host} — see docs/WHITELABEL.md §10.',
    'Privacy policy URL (Play Console requires one).',
    'Internal-track upload via Play Console.',
  ];
  for (final i in items) {
    p.info('  - $i');
  }
  p.info('');
  p.success('Done.');
}

String _slug(String name) {
  return name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

class _SubprocessFailure implements Exception {
  _SubprocessFailure(this.label, this.result);
  final String label;
  final ProcessResult result;
  @override
  String toString() {
    // Truncate noisy stdout/stderr so the wizard's final error line
    // stays scannable. Full output is still available via --verbose at
    // tool/init.dart.
    final tail = _tail(
      [result.stdout?.toString() ?? '', result.stderr?.toString() ?? '']
          .where((s) => s.isNotEmpty)
          .join('\n'),
      lines: 10,
    );
    final body = tail.isEmpty ? '' : '\n  $tail';
    return '$label exited with code ${result.exitCode}$body';
  }

  static String _tail(String s, {required int lines}) {
    final all = s.trimRight().split('\n');
    if (all.length <= lines) return all.join('\n  ');
    return all.sublist(all.length - lines).join('\n  ');
  }
}
