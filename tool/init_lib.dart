// Pure logic for `tool/init.dart` — kept here so it can be unit-tested
// without spinning up a TUI. Anything that needs a [Logger] or stdin lives
// in init.dart proper.

// ignore_for_file: always_use_package_imports

import 'dart:io';

import 'configure_lib.dart';

/// All identity values the wizard collects + writes into the YAML.
class WizardAnswers {
  WizardAnswers({
    required this.name,
    required this.host,
    required this.homeUrl,
    required this.applicationId,
    required this.admobAppId,
    required this.version,
    required this.themeBrightness,
    required this.themePrimary,
    required this.disclaimerEnabled,
    required this.disclaimerBody,
    required this.adsEnabled,
    required this.fcmEnabled,
    required this.iapEnabled,
    required this.fileUploadsEnabled,
    required this.scannerEnabled,
    required this.splashEnabled,
    required this.splashTagline,
    required this.splashBackgroundColor,
  });

  final String name;
  final String host;
  final String homeUrl;
  final String applicationId;
  final String? admobAppId;
  final String version;
  final String themeBrightness; // light | dark | system
  final String themePrimary; // hex
  final bool disclaimerEnabled;
  final String disclaimerBody;
  final bool adsEnabled;
  final bool fcmEnabled;
  final bool iapEnabled;
  final bool fileUploadsEnabled;
  final bool scannerEnabled;
  final bool splashEnabled;
  final String splashTagline;
  final String splashBackgroundColor;
}

/// Validates a host string. Bare host expected — no scheme, no path.
String? validateHost(String input) {
  final s = input.trim();
  if (s.isEmpty) return 'host cannot be empty';
  if (s.contains('://'))
    return 'host must not include a scheme (drop "https://")';
  if (s.contains('/')) return 'host must not include a path';
  if (s.contains(' ')) return 'host must not contain spaces';
  if (!RegExp(r'^[a-z0-9.-]+$').hasMatch(s)) {
    return 'host must contain only lowercase letters, digits, "." and "-"';
  }
  if (!s.contains('.')) return 'host must include a dot (e.g. "example.com")';
  return null;
}

/// Validates a `home_url`. Must be HTTPS, must point at the configured host,
/// and must include a scheme.
String? validateHomeUrl(String input, {required String host}) {
  final s = input.trim();
  if (s.isEmpty) return 'home_url cannot be empty';
  final uri = Uri.tryParse(s);
  if (uri == null || !uri.hasScheme) {
    return 'home_url must be a full URL (e.g. "https://$host/")';
  }
  if (uri.scheme != 'https' && uri.scheme != 'http') {
    return 'home_url must use http(s)://, got "${uri.scheme}://"';
  }
  if (uri.host.isEmpty) return 'home_url must have a host';
  if (uri.host != host) {
    return 'home_url host "${uri.host}" does not match app.host "$host"';
  }
  return null;
}

/// Validates an Android applicationId. Reverse-DNS, lowercase, two or
/// more segments, ASCII identifiers per segment.
String? validateApplicationId(String input) {
  final s = input.trim();
  if (s.isEmpty) return 'application_id cannot be empty';
  final ok = RegExp(r'^[a-z][a-z0-9_]*(\.[a-z0-9_]+)+$').hasMatch(s);
  if (!ok) {
    return 'application_id must be reverse-DNS, lowercase '
        '(e.g. "com.yourcompany.yourapp")';
  }
  return null;
}

/// Validates an AdMob App ID. App IDs use a `~`; Unit IDs use a `/`.
/// Returning null means valid (or empty/skipped).
String? validateAdmobAppId(String input) {
  final s = input.trim();
  if (s.isEmpty) return null; // empty is allowed (ads disabled)
  if (!s.startsWith('ca-app-pub-')) {
    return 'AdMob App ID must start with "ca-app-pub-"';
  }
  if (s.contains('/')) {
    return '"$s" looks like an Ad Unit ID (contains "/"). The App ID '
        'has a "~". Unit IDs go under ads.placements.*.ad_unit_id.';
  }
  if (!s.contains('~')) {
    return 'AdMob App ID is missing the "~" separator';
  }
  return null;
}

/// Validates a `<semver>+<build>` version string.
String? validateVersion(String input) {
  final s = input.trim();
  if (s.isEmpty) return 'version cannot be empty';
  if (!RegExp(r'^\d+\.\d+\.\d+\+\d+$').hasMatch(s)) {
    return 'version must look like "1.0.0+1"';
  }
  return null;
}

/// Validates a hex color. Accepts 3 / 6 / 8 char forms with or without '#'.
String? validateHexColor(String input) {
  final s = input.trim().toUpperCase().replaceAll('#', '');
  if (s.isEmpty) return 'color cannot be empty';
  if (![3, 6, 8].contains(s.length)) {
    return 'color must be 3, 6, or 8 hex chars (got ${s.length})';
  }
  if (!RegExp(r'^[0-9A-F]+$').hasMatch(s)) {
    return 'color must contain only 0-9 and A-F';
  }
  return null;
}

/// A reasonable default disclaimer body interpolating the host + name.
String defaultDisclaimerBody({required String host, required String name}) {
  return 'This app ($name) is an unofficial WebView wrapper around $host.\n'
      'It is not affiliated with or endorsed by the operator of $host.\n'
      'Content is provided as-is by $host; the publisher of this app is\n'
      'not responsible for the accuracy or availability of that content.\n\n'
      'By tapping "I understand", you accept these terms and use the app\n'
      'for personal, development, or educational purposes.';
}

/// Heuristic: does the given host look third-party? "third-party" here
/// just means "not obviously yours" — used to default the disclaimer
/// prompt to ON. The user always confirms.
bool looksThirdParty(String host) {
  // Common public sites that integrators are likely to wrap unofficially.
  // The list is intentionally short — we err on the side of suggesting
  // disclaimer-on; the user can decline.
  const wellKnownThirdParty = {
    'wikipedia.org',
    'reddit.com',
    'github.com',
    'youtube.com',
    'twitter.com',
    'x.com',
    'medium.com',
    'hackernews.com',
    'news.ycombinator.com',
    'blockchair.com',
    'etherscan.io',
    'coinmarketcap.com',
    'coingecko.com',
  };
  for (final h in wellKnownThirdParty) {
    if (host == h || host.endsWith('.$h')) return true;
  }
  return false;
}

/// Renders a fresh `assets/webview_config.yaml` from the wizard answers.
/// We hand-write rather than YAML-serialize because we want comments
/// preserved and the layout to match the live demo file.
String renderWebViewConfigYaml(WizardAnswers a) {
  final buf = StringBuffer();
  buf.writeln('# Generated by `dart run tool/init.dart`. Hand-edit any time;');
  buf.writeln('# re-run `dart run tool/configure.dart` to propagate changes.');
  buf.writeln();

  buf.writeln('app:');
  buf.writeln('  name: ${_yamlString(a.name)}');
  buf.writeln('  host: ${_yamlString(a.host)}');
  buf.writeln('  home_url: ${_yamlString(a.homeUrl)}');
  buf.writeln('  application_id: ${_yamlString(a.applicationId)}');
  if (a.admobAppId != null && a.admobAppId!.isNotEmpty) {
    buf.writeln('  admob_app_id: ${_yamlString(a.admobAppId!)}');
  } else {
    buf.writeln('  # admob_app_id: "ca-app-pub-XXXXXXXXXX~YYYYYYYYYY"');
  }
  buf.writeln('  version: ${_yamlString(a.version)}');
  buf.writeln();

  buf.writeln('flutter_ui:');
  buf.writeln('  theme:');
  buf.writeln('    brightness: ${_yamlString(a.themeBrightness)}');
  buf.writeln('    primary: ${_yamlString(a.themePrimary)}');
  buf.writeln('    use_material3: true');
  buf.writeln('    font_family: "Inter"');
  buf.writeln('  layout:');
  buf.writeln('    scaffold: "drawer"');
  buf.writeln('    appbar:');
  buf.writeln('      visible: true');
  buf.writeln('      actions:');
  buf.writeln('        - id: "refresh"');
  buf.writeln('          icon: "Icons.refresh"');
  buf.writeln('          action: "webview.reload"');
  buf.writeln('    drawer:');
  buf.writeln('      visible: true');
  buf.writeln('      header:');
  buf.writeln('        title: ${_yamlString(a.name)}');
  buf.writeln('      items:');
  buf.writeln('        - title: "Home"');
  buf.writeln('          icon: "Icons.home_outlined"');
  buf.writeln('          route: "/web/home"');
  buf.writeln('        - title: "Settings"');
  buf.writeln('          icon: "Icons.settings_outlined"');
  buf.writeln('          route: "/native/settings"');
  buf.writeln('  routes:');
  buf.writeln('    - path: "/web/home"');
  buf.writeln('      kind: "webview"');
  buf.writeln('      title: "Home"');
  buf.writeln('      url: ${_yamlString(a.homeUrl)}');
  buf.writeln('      pull_to_refresh: true');
  buf.writeln('      appbar_visible: true');
  buf.writeln('    - path: "/native/settings"');
  buf.writeln('      kind: "native"');
  buf.writeln('      title: "Settings"');
  buf.writeln('      icon: "Icons.settings_outlined"');
  buf.writeln();

  buf.writeln('navigation:');
  buf.writeln('  external_allowlist:');
  buf.writeln('    - ${_yamlString(a.host)}');
  buf.writeln('  deep_links:');
  buf.writeln('    enable: true');
  buf.writeln('    hosts:');
  buf.writeln('      - ${_yamlString(a.host)}');
  buf.writeln();

  buf.writeln('webview_settings:');
  buf.writeln('  javascript_enabled: true');
  buf.writeln('  dom_storage_enabled: true');
  buf.writeln();

  buf.writeln('file_uploads:');
  buf.writeln('  enabled: ${a.fileUploadsEnabled}');
  buf.writeln('  capture_camera: ${a.fileUploadsEnabled}');
  buf.writeln('  mime_types: ["*/*"]');
  buf.writeln();

  buf.writeln('downloads:');
  buf.writeln('  enabled: true');
  buf.writeln('  use_android_download_manager: true');
  buf.writeln('  support_blob_urls: true');
  buf.writeln();

  buf.writeln('splash:');
  buf.writeln('  enabled: ${a.splashEnabled}');
  buf.writeln('  timeout_ms: 1500');
  buf.writeln('  fade_out_ms: 300');
  buf.writeln('  background_color: ${_yamlString(a.splashBackgroundColor)}');
  if (a.splashTagline.isNotEmpty) {
    buf.writeln('  tagline: ${_yamlString(a.splashTagline)}');
  }
  buf.writeln();

  buf.writeln('offline_local_html:');
  buf.writeln('  fallback_when_offline: true');
  buf.writeln('  index_asset: "offline/index.html"');
  buf.writeln();

  buf.writeln('ads:');
  buf.writeln('  enabled: ${a.adsEnabled}');
  buf.writeln('  consent_gate_with_ump: ${a.adsEnabled}');
  buf.writeln('  placements:');
  buf.writeln('    global_banner:');
  buf.writeln('      screen_scope: "all"');
  buf.writeln('      format: "banner_adaptive"');
  buf.writeln('      position: "bottom"');
  buf.writeln('      ad_unit_id: "ca-app-pub-3940256099942544/6300978111"');
  buf.writeln();

  buf.writeln('billing:');
  buf.writeln('  inapp_enabled: ${a.iapEnabled}');
  buf.writeln('  product_ids: []');
  buf.writeln();

  buf.writeln('rating_prompt:');
  buf.writeln('  enabled: true');
  buf.writeln('  after_launches: 5');
  buf.writeln();

  buf.writeln('js_bridge:');
  buf.writeln('  enabled: true');
  buf.writeln('  name: "WebSightBridge"');
  buf.writeln('  secure_origin_only: true');
  buf.writeln('  methods:');
  buf.writeln('    - "scanBarcode(callbackFn)"');
  buf.writeln('    - "share(text)"');
  buf.writeln('    - "getDeviceInfo()"');
  buf.writeln('    - "downloadBlob(url, filename?)"');
  buf.writeln('    - "openExternal(url)"');
  buf.writeln('    - "registerHttpDownload(url, opts?)"');
  buf.writeln('  inbound_events:');
  buf.writeln('    - event: "openNative"');
  buf.writeln('      args: ["route"]');
  buf.writeln('      action: "navigate:{route}"');
  buf.writeln('    - event: "toast"');
  buf.writeln('      args: ["message"]');
  buf.writeln('      action: "ui.toast:{message}"');
  buf.writeln();

  buf.writeln('security:');
  buf.writeln('  restrict_to_hosts:');
  buf.writeln('    - ${_yamlString(a.host)}');
  buf.writeln();

  buf.writeln('analytics_crash:');
  buf.writeln('  analytics: true');
  buf.writeln('  crashlytics: true');
  buf.writeln();

  buf.writeln('updates:');
  buf.writeln('  in_app_updates: "flexible"');
  buf.writeln();

  buf.writeln('notifications:');
  buf.writeln('  post_notifications_permission: true');
  buf.writeln('  fcm_enabled: ${a.fcmEnabled}');
  buf.writeln();

  buf.writeln('behavior_overrides:');
  buf.writeln('  back_button:');
  buf.writeln('    confirm_before_exit: true');
  buf.writeln('  error_pages:');
  buf.writeln('    show_offline_page: true');
  buf.writeln('    retry_button: true');
  buf.writeln();

  buf.writeln('legal:');
  buf.writeln('  unofficial_disclaimer:');
  buf.writeln('    enabled: ${a.disclaimerEnabled}');
  buf.writeln('    title: "Unofficial app"');
  buf.writeln('    body: |');
  for (final line in a.disclaimerBody.split('\n')) {
    buf.writeln('      $line');
  }
  buf.writeln('    accept_label: "I understand"');
  buf.writeln('    decline_label: "Exit"');
  buf.writeln('    require_accept: true');

  return buf.toString();
}

String _yamlString(String s) {
  // Conservative: always quote, escape backslashes + quotes.
  final esc = s.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  return '"$esc"';
}

/// Pubspec patches the wizard makes after writing the YAML — adds the
/// flutter_launcher_icons + flutter_native_splash blocks if the user
/// chose splash/icon paths. Idempotent.
String patchPubspecForLaunchAssets(
  String pubspec, {
  required String? launcherIconPath,
  required bool splashEnabled,
  required String splashBg,
  required String? splashImageAsset,
}) {
  var out = pubspec;

  if (launcherIconPath != null) {
    if (!out.contains('flutter_launcher_icons:')) {
      out += '\n\nflutter_launcher_icons:\n'
          '  android: "ic_launcher"\n'
          '  ios: false\n'
          '  image_path: ${_yamlString(launcherIconPath)}\n'
          '  adaptive_icon_background: ${_yamlString(splashBg)}\n'
          '  adaptive_icon_foreground: ${_yamlString(launcherIconPath)}\n'
          '  min_sdk_android: 24\n';
    }
  }

  if (splashEnabled) {
    if (!out.contains('flutter_native_splash:')) {
      final imageLine = splashImageAsset == null
          ? '  # image: assets/splash/logo.png'
          : '  image: $splashImageAsset';
      out += '\n\nflutter_native_splash:\n'
          '  color: ${_yamlString(splashBg)}\n'
          '$imageLine\n'
          '  android_12:\n'
          '    color: ${_yamlString(splashBg)}\n'
          '${imageLine.replaceFirst('  ', '    ')}\n'
          '  fullscreen: false\n'
          '  android: true\n'
          '  ios: false\n'
          '  web: false\n';
    }
  }

  return out;
}

/// Writes a `key.properties` skeleton (gitignored). Caller is responsible
/// for prompting the keystore values; this just renders the file from
/// already-collected inputs.
String renderKeyProperties({
  required String storePassword,
  required String keyPassword,
  required String keyAlias,
  required String storeFile,
}) {
  return 'storePassword=$storePassword\n'
      'keyPassword=$keyPassword\n'
      'keyAlias=$keyAlias\n'
      'storeFile=$storeFile\n';
}

/// Existing wizard state — used to detect whether init has already run
/// (so we skip steps idempotently on resume).
class ProjectState {
  ProjectState({
    required this.hasIdentityConfigured,
    required this.hasFirebaseReal,
    required this.hasKeyProperties,
    required this.hasLauncherIcon,
    required this.hasSplashImage,
  });

  final bool hasIdentityConfigured;
  final bool hasFirebaseReal;
  final bool hasKeyProperties;
  final bool hasLauncherIcon;
  final bool hasSplashImage;

  static ProjectState detect(Directory projectRoot) {
    final yaml = File(
      '${projectRoot.path}/assets/webview_config.yaml',
    );
    var hasIdentity = false;
    if (yaml.existsSync()) {
      final body = yaml.readAsStringSync();
      // Heuristic: not the demo-template host.
      hasIdentity = !body.contains('host: "flutter.dev"') &&
          !body.contains('YOUR_PRIMARY_HOST_HERE') &&
          body.contains('application_id:');
    }
    final fb = File('${projectRoot.path}/lib/firebase_options.dart');
    final fbReal =
        fb.existsSync() && !fb.readAsStringSync().contains('YOUR_API_KEY');
    final keyProps =
        File('${projectRoot.path}/android/key.properties').existsSync();
    final icon =
        File('${projectRoot.path}/assets/launcher/icon.png').existsSync();
    final splash =
        File('${projectRoot.path}/assets/splash/logo.png').existsSync();
    return ProjectState(
      hasIdentityConfigured: hasIdentity,
      hasFirebaseReal: fbReal,
      hasKeyProperties: keyProps,
      hasLauncherIcon: icon,
      hasSplashImage: splash,
    );
  }
}

/// Re-export for callers that want to validate AppIdentity directly.
/// init.dart synthesizes one from the wizard answers and runs all the
/// configure_lib regex ops via the same code path the standalone
/// configure command uses.
AppIdentity wizardAnswersToIdentity(WizardAnswers a) {
  return AppIdentity(
    name: a.name,
    host: a.host,
    applicationId: a.applicationId,
    admobAppId: a.admobAppId,
    version: a.version,
  );
}
