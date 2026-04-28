// `tool/` is outside `lib/`, so it cannot use a `package:websight/...`
// import for its sibling library. The `always_use_package_imports` lint
// is suppressed only on this line for that reason.
// ignore_for_file: always_use_package_imports

// CLI entry point for `dart run tool/configure.dart`.
//
// Propagates app-identity values from assets/webview_config.yaml into the
// build files Android requires to host them literally (Gradle, manifest,
// res/values, pubspec). The YAML stays the single source of truth; this
// script keeps the rest in sync.
//
// Logic lives in tool/configure_lib.dart so it can be unit-tested without
// spawning a subprocess.
//
// Usage:
//   dart run tool/configure.dart           # apply changes
//   dart run tool/configure.dart --dry-run # preview without writing
//   dart run tool/configure.dart --config path/to/file.yaml

import 'dart:io';

import 'configure_lib.dart';

const String _defaultConfigPath = 'assets/webview_config.yaml';

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final configPath = _argValue(args, '--config') ?? _defaultConfigPath;

  late final AppIdentity identity;
  try {
    identity = AppIdentity.fromYamlFile(configPath);
    identity.validate();
  } on ConfigureError catch (e) {
    stderr.writeln('configure: ${e.message}');
    exit(2);
  }

  final ops = <Op>[
    gradleOp(identity),
    manifestOp(identity),
    stringsOp(identity),
    pubspecOp(identity),
    yamlHostsOp(identity, configPath),
  ];

  final changed = <String>[];
  final unchanged = <String>[];
  final missing = <String>[];

  for (final op in ops) {
    final file = File(op.path);
    if (!file.existsSync()) {
      missing.add(op.path);
      continue;
    }
    final original = file.readAsStringSync();
    final updated = op.transform(original);
    if (updated == original) {
      unchanged.add(op.path);
      continue;
    }
    if (!dryRun) file.writeAsStringSync(updated);
    changed.add(op.path);
  }

  _printSummary(identity, changed, unchanged, missing, dryRun);
  if (missing.isNotEmpty) exitCode = 1;
}

String? _argValue(List<String> args, String flag) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == flag && i + 1 < args.length) return args[i + 1];
    if (args[i].startsWith('$flag=')) return args[i].substring(flag.length + 1);
  }
  return null;
}

void _printSummary(
  AppIdentity i,
  List<String> changed,
  List<String> unchanged,
  List<String> missing,
  bool dryRun,
) {
  final mode = dryRun ? '[dry-run] ' : '';
  stdout.writeln('${mode}WebSight configure');
  stdout.writeln('  app.name              = ${i.name}');
  stdout.writeln('  app.host              = ${i.host}');
  stdout.writeln(
      '  app.application_id    = ${i.applicationId ?? "(unset — gradle untouched)"}');
  stdout.writeln(
      '  app.admob_app_id      = ${i.admobAppId ?? "(unset — manifest untouched)"}');
  stdout.writeln(
      '  app.version           = ${i.version ?? "(unset — pubspec untouched)"}');
  stdout.writeln();
  if (changed.isNotEmpty) {
    stdout.writeln('${mode}Changed:');
    for (final p in changed) {
      stdout.writeln('  ✓ $p');
    }
  }
  if (unchanged.isNotEmpty) {
    stdout.writeln('${mode}Already up to date:');
    for (final p in unchanged) {
      stdout.writeln('  · $p');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln('${mode}Missing files (script could not run):');
    for (final p in missing) {
      stderr.writeln('  ✗ $p');
    }
  }
  stdout.writeln();
  stdout.writeln('Next steps:');
  stdout.writeln('  1. Drop your launcher icon at assets/launcher/icon.png');
  stdout.writeln('     (icon.kitchen is a good visual generator), then:');
  stdout.writeln('     `dart run flutter_launcher_icons`');
  stdout.writeln('     `dart run flutter_native_splash:create`');
  stdout.writeln('  2. Run `flutterfire configure` to wire Firebase.');
  stdout.writeln('  3. (Optional) `dart run change_app_package_name:main '
      '${i.applicationId ?? "com.yourcompany.yourapp"}` to rename the Kotlin');
  stdout.writeln('     package directory to match. Run BEFORE re-running this');
  stdout
      .writeln('     script — otherwise it will overwrite the applicationId.');
  stdout.writeln(
      '  4. `flutter pub get && flutter build apk --debug` to verify.');
  stdout.writeln();
  stdout.writeln('See docs/WHITELABEL.md for the full end-to-end guide.');
}
