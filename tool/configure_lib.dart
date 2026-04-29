// Pure logic behind `tool/configure.dart`. Kept in a sibling library so the
// substitution rules can be unit-tested without spawning a subprocess.

import 'dart:io';

import 'package:yaml/yaml.dart';

class AppIdentity {
  AppIdentity({
    required this.name,
    required this.host,
    required this.applicationId,
    required this.admobAppId,
    required this.version,
  });

  final String name;
  final String host;
  final String? applicationId;
  final String? admobAppId;
  final String? version;

  /// Reads the `app:` block from the YAML at [path]. Missing optional keys
  /// come back as null and the corresponding files are left untouched.
  factory AppIdentity.fromYamlString(String yaml, {String sourcePath = ''}) {
    final raw = loadYaml(yaml);
    final root = (raw is Map && raw['webview_config'] is Map)
        ? raw['webview_config'] as Map
        : raw as Map;
    final app = root['app'];
    if (app is! Map) {
      throw ConfigureError(
          '$sourcePath is missing an `app:` block at the top level');
    }
    String? str(Object? v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    return AppIdentity(
      name: str(app['name']) ?? 'WebSight',
      host: str(app['host']) ?? '',
      applicationId: str(app['application_id']),
      admobAppId: str(app['admob_app_id']),
      version: str(app['version']),
    );
  }

  factory AppIdentity.fromYamlFile(String path) {
    final f = File(path);
    if (!f.existsSync()) {
      throw ConfigureError('config file not found at $path');
    }
    return AppIdentity.fromYamlString(f.readAsStringSync(), sourcePath: path);
  }

  /// Throws [ConfigureError] if any value is malformed. Empty optional
  /// values are allowed; only present-but-malformed values fail validation.
  void validate() {
    final errors = <String>[];
    if (host.isEmpty) {
      errors.add('app.host must be set (got empty value)');
    } else if (host.contains('://') || host.contains('/')) {
      errors.add('app.host must be a bare host, not a URL (got "$host")');
    }
    if (applicationId != null) {
      final ok =
          RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$').hasMatch(applicationId!);
      if (!ok) {
        errors.add('app.application_id "$applicationId" is not a valid '
            'Android applicationId (lowercase reverse-DNS expected)');
      }
    }
    if (admobAppId != null && !admobAppId!.contains('~')) {
      errors.add('app.admob_app_id "$admobAppId" should contain a "~" '
          '(App ID format), not a "/" (that is a Unit ID)');
    }
    if (errors.isNotEmpty) {
      throw ConfigureError(errors.join('\n'));
    }
  }
}

class ConfigureError implements Exception {
  ConfigureError(this.message);
  final String message;
  @override
  String toString() => 'ConfigureError: $message';
}

abstract class Op {
  String get path;
  String transform(String input);
}

class RegexOp extends Op {
  RegexOp(this.path, this.swaps);
  @override
  final String path;
  final List<Swap> swaps;

  @override
  String transform(String input) {
    var out = input;
    for (final s in swaps) {
      out = out.replaceAllMapped(s.pattern, s.replacement);
    }
    return out;
  }
}

class Swap {
  Swap(this.pattern, this.replacement);
  final RegExp pattern;
  final String Function(Match) replacement;
}

Op gradleOp(AppIdentity i) {
  final swaps = <Swap>[];
  if (i.applicationId != null) {
    // Anchor to `defaultConfig { ... }` so productFlavor blocks (Play vs
    // FOSS, dev vs prod) keep their own applicationId / suffix overrides.
    // Without the anchor every `applicationId =` in the file gets
    // clobbered to the same value the moment a flavor is added.
    swaps.add(Swap(
      RegExp(r'(defaultConfig\s*\{[\s\S]*?applicationId\s*=\s*")[^"]*(")'),
      (m) => '${m[1]}${i.applicationId}${m[2]}',
    ));
    // `namespace` is a top-level `android { }` property and does not
    // appear inside flavors; anchor to the android block to be safe.
    swaps.add(Swap(
      RegExp(r'(android\s*\{[\s\S]*?namespace\s*=\s*")[^"]*(")'),
      (m) => '${m[1]}${i.applicationId}${m[2]}',
    ));
  }
  return RegexOp('android/app/build.gradle.kts', swaps);
}

Op manifestOp(AppIdentity i) {
  final swaps = <Swap>[];
  // Anchor the host swap to the autoVerify intent-filter. Without the
  // anchor, every `<data android:host="...">` gets rewritten — including
  // hosts the integrator added for unrelated intent-filters (oauth
  // callback, share-target, custom scheme, etc.).
  swaps.add(Swap(
    RegExp(
      r'(<intent-filter[^>]*\bandroid:autoVerify="true"'
      r'[\s\S]*?<data\s+android:host=")[^"]*(")',
    ),
    (m) => '${m[1]}${i.host}${m[2]}',
  ));
  if (i.admobAppId != null) {
    swaps.add(Swap(
      RegExp(
        r'(android:name="com\.google\.android\.gms\.ads\.APPLICATION_ID"'
        r'[\s\S]*?android:value=")[^"]*(")',
      ),
      (m) => '${m[1]}${i.admobAppId}${m[2]}',
    ));
  }
  return RegexOp('android/app/src/main/AndroidManifest.xml', swaps);
}

Op stringsOp(AppIdentity i) {
  return RegexOp('android/app/src/main/res/values/strings.xml', <Swap>[
    Swap(
      RegExp(r'(<string\s+name="app_name">)[^<]*(</string>)'),
      (m) => '${m[1]}${xmlEscape(i.name)}${m[2]}',
    ),
  ]);
}

Op pubspecOp(AppIdentity i) {
  final swaps = <Swap>[
    Swap(
      RegExp(r'^name:\s*.+$', multiLine: true),
      (_) => 'name: ${pubspecName(i.name)}',
    ),
  ];
  if (i.version != null) {
    swaps.add(Swap(
      RegExp(r'^version:\s*.+$', multiLine: true),
      (_) => 'version: ${i.version}',
    ));
  }
  return RegexOp('pubspec.yaml', swaps);
}

Op yamlHostsOp(AppIdentity i, String yamlPath) {
  // Replaces only the FIRST entry under `restrict_to_hosts:` and under
  // `deep_links.hosts:`. Subsequent entries are intentionally preserved
  // — some forks add CDN / login subdomains that the script has no way
  // to know about. Use [auditYamlHostMultiplicity] to surface a warning
  // when the source had multiple entries.
  return RegexOp(yamlPath, <Swap>[
    Swap(
      RegExp(
        r'(restrict_to_hosts:\s*\n\s+- ")[^"]*(")',
        multiLine: true,
      ),
      (m) => '${m[1]}${i.host}${m[2]}',
    ),
    Swap(
      RegExp(
        r'(deep_links:\s*\n\s+enable:\s*\w+\s*\n\s+hosts:\s*\n\s+- ")[^"]*(")',
        multiLine: true,
      ),
      (m) => '${m[1]}${i.host}${m[2]}',
    ),
  ]);
}

class HostMultiplicity {
  HostMultiplicity({required this.restrictHosts, required this.deepLinkHosts});
  final int restrictHosts;
  final int deepLinkHosts;
  bool get hasExtraEntries => restrictHosts > 1 || deepLinkHosts > 1;
}

/// Counts list entries under `restrict_to_hosts:` and `deep_links.hosts:`
/// in a YAML string. Used by `tool/configure.dart` to warn the integrator
/// when their config had additional host entries that [yamlHostsOp]
/// intentionally left untouched.
HostMultiplicity auditYamlHostMultiplicity(String yaml) {
  return HostMultiplicity(
    restrictHosts: _countListEntriesUnder(yaml, key: 'restrict_to_hosts'),
    deepLinkHosts: _countListEntriesUnderDeepLinks(yaml),
  );
}

int _countListEntriesUnder(String yaml, {required String key}) {
  final lines = yaml.split('\n');
  var i = 0;
  while (i < lines.length) {
    if (RegExp('^\\s*$key:\\s*\$').hasMatch(lines[i])) {
      return _countListItemsAfter(lines, i + 1);
    }
    i++;
  }
  return 0;
}

int _countListEntriesUnderDeepLinks(String yaml) {
  final lines = yaml.split('\n');
  var inDeepLinks = false;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (RegExp(r'^\s*deep_links:\s*$').hasMatch(line)) {
      inDeepLinks = true;
      continue;
    }
    if (inDeepLinks && RegExp(r'^\s*hosts:\s*$').hasMatch(line)) {
      return _countListItemsAfter(lines, i + 1);
    }
    // A new top-level key (no leading whitespace) ends the deep_links
    // block before we found `hosts:` — guard against false matches in
    // sibling sections.
    if (inDeepLinks && line.isNotEmpty && !line.startsWith(' ')) {
      inDeepLinks = false;
    }
  }
  return 0;
}

int _countListItemsAfter(List<String> lines, int startIdx) {
  var count = 0;
  String? indent;
  for (var i = startIdx; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final leading = RegExp(r'^(\s*)').firstMatch(line)![1]!;
    final isItem = line.trimLeft().startsWith('- ');
    if (!isItem) {
      // A non-item line at or below the list's indent means the list
      // ended.
      if (indent == null || leading.length <= indent.length) break;
      continue;
    }
    indent ??= leading;
    if (leading.length < indent.length) break;
    count++;
  }
  return count;
}

String pubspecName(String displayName) {
  final cleaned = displayName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return cleaned.isEmpty ? 'websight' : cleaned;
}

String xmlEscape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
