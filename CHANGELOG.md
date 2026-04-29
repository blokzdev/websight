# Changelog

All notable changes to WebSight are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-04-29

First public release. WebSight is a forkable Android-only WebView app
template driven by a single `webview_config.yaml`. Apache 2.0
licensed.

### Added
- **Setup wizard** — `dart run tool/init.dart`. Walks identity, theme,
  disclaimer, features, splash; writes `assets/webview_config.yaml`;
  runs the propagator; offers icons, native splash, `flutterfire
  configure`, keystore generation, and a smoke build. Two modes:
  rich TUI (mason_logger — colors, spinners) or plain prompts (works
  in CI logs / dumb terminals / Windows cmd). User picks at start;
  `--plain` and `--rich` flags force. `--skip-firebase`,
  `--skip-keystore`, `--skip-smoke`, `--skip-pub-get` for resumed
  runs. SRP split: `tool/init/prompter.dart` (Prompter +
  PlainPrompter + RichPrompter), `tool/init/runner.dart` (step
  orchestration), `tool/init.dart` (CLI wrapper, mode picker).
- **Project doctor** — `dart run tool/doctor.dart`. Surveys
  toolchain (Flutter, JDK 17), project identity (custom host /
  applicationId), Firebase wiring (placeholder vs real), launcher
  icon, splash image, signing, AdMob App ID (test vs real),
  deep-link host vs YAML, leftover template placeholders. Each
  result carries an actionable fix-it command. Exits 1 on any hard
  fail so you can wire it as a CI step.
- **Wizard validators** in `tool/init_lib.dart` —
  validateHost / validateHomeUrl / validateApplicationId /
  validateAdmobAppId (rejects unit-id-shaped values) /
  validateVersion / validateHexColor — plus
  `looksThirdParty(host)` heuristic that defaults the disclaimer
  prompt ON for well-known public sites.
- **README + WHITELABEL** updates point the fast path at
  `dart run tool/init.dart`; the manual cheat sheet remains for
  full-control users. Maintainer note in WHITELABEL covers the
  GitHub "Template repository" flag.
- **Whitelabel guide** (`docs/WHITELABEL.md`) — end-to-end recipe for
  taking the template, pointing it at any web app's domain, and
  shipping a signed AAB to Play. Covers toolchain prereqs, identity,
  icon generation (icon.kitchen + flutter_launcher_icons), splash,
  Firebase + AdMob + IAP setup, signing, on-device smoke checklist,
  Play Console listing + privacy + Data Safety, and trademark / ToS /
  financial-services policy guidance for third-party-site wrappers.
- **`legal:` config block** (`legal.unofficial_disclaimer.*`) — opt-in
  first-launch disclaimer dialog. New `DisclaimerController` (backed
  by `shared_preferences`) and `DisclaimerGate` widget wrap every
  routed screen via `MaterialApp.router`'s `builder:`. The dialog is
  modal and non-dismissable; on accept, the choice is persisted under
  a key derived from the body's hash so any edit to the disclaimer
  text invalidates prior acceptances. On decline with
  `require_accept: true`, the app exits via `SystemNavigator.pop()`.
  Recommended for any whitelabel of a site you don't own (personal /
  dev / educational use).
- **`examples/blockchair.yaml`** + `examples/README.md` — drop-in
  starter config demonstrating a third-party-site whitelabel: ads
  off, file uploads off, disclaimer on with blockchair-specific body,
  splash + offline + downloads on. Header comment makes the
  trademark/ToS responsibility explicit.
- `tool/configure.dart`'s "Next steps" output now points at icon
  generation (icon.kitchen + `flutter_launcher_icons`), the package-
  rename ordering caveat, and `docs/WHITELABEL.md` for the full
  guide.
- v1.0 hardening sweep: 24 findings from a 3-agent audit landed in 10
  reviewable chunks. Headlines below; see commit messages on the
  branch for the per-finding rationale.
  * Wiring fixes — file uploads now actually work (a real method-channel
    pickFiles handler routes ACTION_GET_CONTENT through MainActivity;
    the dead WebSightChromeClient.kt is gone), and the AppBar
    `webview.reload` action signals the active WebViewScreen via a new
    `WebViewSignals` ChangeNotifier instead of being a no-op.
  * Native bugs — ScannerActivity gates CAMERA permission via the
    Activity Result API and uses `AtomicBoolean.compareAndSet` so
    multi-barcode frames cannot fire the listener twice; downloadBlob
    moved off the UI thread to a dedicated executor with a 50 MiB cap
    and rolls back the MediaStore pending row on write failure.
  * Security — FCM PendingIntent uses a unique requestCode
    (notificationId) so push-tap deep links no longer deliver stale
    `route` extras; inbound `navigate:{route}` actions are allow-listed
    against `flutter_ui.routes` so a page cannot push the host into an
    undeclared surface.
  * Honest config — `docs/internal/config-reference.yaml` rewritten
    around explicit ✅ / 🛠 / 🚧 annotations; ~25 keys that were
    parsed-and-discarded moved into a fenced "RESERVED / not yet wired"
    section so integrators stop expecting runtime effect from them.
  * Lifecycle — FcmController disposes its three FirebaseMessaging
    listeners; AppShell memoizes the last-loaded ad route so rotation /
    theme changes stop thrashing the banner; WebsightWebViewController
    tracks a `_disposed` flag and short-circuits async injection
    chains; UmpConsent skips the network round-trip when
    canRequestAds() already returns true.
  * Error visibility — BillingController surfaces failures via a
    `lastError` field + Crashlytics.recordError so production billing
    failures stop being silent debugPrints.
  * Tests — extracted `lib/shell/route_paths.dart` (yamlPathToGoRouter,
    stripParameterizedTail, routeMatchesPattern, substituteUrlParams,
    isAllowedNavigationTarget) with full unit coverage; deduplicates
    three previously-private copies of the same logic across
    app_router, app_shell, and js_bridge.
  * CI — runs `dart format` over `tool/` too; advisory
    `flutter pub outdated` on every PR; new manifest-sanity step fails
    CI when the deep-link host has drifted from `app.host`.
  * Visual — adaptive launcher icon (mipmap-anydpi-v26/ic_launcher.xml)
    + monochrome glyph + colors.xml for Android 8+ adaptive rendering
    and Android 13+ themed icons; flutter_launcher_icons added as a
    dev dep with a starter pubspec block.
  * Bridge ergonomics — public
    `WebSightBridge.dispatch(eventName, params)` JS method and a
    "Built-in action grammars" table in docs/bridge-api.md so
    integrators stop reaching for the internal `_postMessage`.
- `tool/configure.dart` — single command that propagates app identity
  from `assets/webview_config.yaml` into the Android files that have to
  host those values literally:
  - `applicationId` + `namespace` in `android/app/build.gradle.kts`
  - deep-link `<data android:host>` and AdMob `APPLICATION_ID`
    meta-data in `AndroidManifest.xml`
  - `<string name="app_name">` in `strings.xml`
  - `name` (snake_case) and `version` in `pubspec.yaml`
  - `security.restrict_to_hosts` and `navigation.deep_links.hosts`
    propagated from `app.host` so the user only edits one host.
  Runs idempotently, supports `--dry-run`, validates inputs (rejects
  empty/malformed `application_id`, AdMob unit-ID-shaped values).
  Logic lives in `tool/configure_lib.dart` and is unit-tested.
- New optional `app:` keys: `application_id`, `admob_app_id`, `version`.
  Backwards compatible — when absent, the corresponding files are left
  untouched.
- README "fork-the-template" workflow rewritten around the new
  `dart run tool/configure.dart` step. Steps that hand-edited Gradle
  and the manifest are gone.
- Configurable in-Flutter splash overlay. New
  `splash.{image_asset, background_color, tagline, fade_out_ms}` keys
  drive `_SplashOverlay`: optional centered logo, optional tagline,
  configurable background that auto-picks a contrasting foreground,
  cross-fade exit via `AnimatedSwitcher`. Falls back to a small
  themed progress indicator when neither image nor tagline is set.
- `flutter_native_splash` wired as a dev dependency with a starter
  `flutter_native_splash:` block in `pubspec.yaml` and an explicit
  `assets/splash/` directory. Documented one-liner regeneration step
  (`dart run flutter_native_splash:create`) in README, alongside the
  in-Flutter splash configuration.
- HTTPS download auto-detection. When `downloads.enabled` and
  `downloads.use_android_download_manager` are both true, a small
  document-level click listener installed by the bridge intercepts
  clicks on `<a download>` elements and `<a>` elements whose href looks
  downloadable (pdf/zip/csv/mp4/apk/...): HTTP/S targets are routed to
  Android's DownloadManager via the new `registerHttpDownload` bridge
  method; blob targets continue through `downloadBlob` to MediaStore.
  Modifier-clicks (Ctrl/Shift/Alt/Meta) are left alone so the page's
  own "open in new tab" semantics still work.
- New `WebSightBridge.registerHttpDownload(url, opts?)` JS method
  resolves with `{ id, filename }`. Documented in
  `docs/bridge-api.md`.
- `ConfigurableNativeScreen` — single widget rendering every `kind: native`
  route. Settings variant auto-derives content from `WebSightConfig` /
  `WebSightFeatures` (app name, host, theme, analytics flags, FCM token,
  IAP product count) and surfaces Privacy/Terms/About routes from the
  config when present. Generic placeholder variant clearly labels the
  route path so it's obvious the screen needs customization.
- Hand-rolled feature config layer (`lib/config/feature_configs.dart`)
  covering splash, offline HTML fallback, custom CSS/JS injection,
  user agent modes, file uploads, downloads, billing, rating prompt,
  FAB, bottom tabs, drawer.
- `ActionDispatcher` resolving YAML action strings
  (`navigate:`, `webview.reload`, `webview.back`, `bridge.<method>`,
  `store.rate`, `noop`).
- Lifecycle controllers: `FcmController` (Firebase Cloud Messaging),
  `BillingController` (in-app purchases), `RatingController`
  (in-app review with launch counter).
- Configurable splash overlay, offline overlay with retry, generic
  error overlay with retry.
- Native `WebSightMessagingService` for FCM with default channel + route
  extra propagation for push-tap deep linking.
- Method-channel handlers in `MainActivity`: `gatherConsent`,
  `scanBarcode`, `downloadBlob`, `registerHttpDownload`, file uploads.
- ProGuard rules, network security config, data extraction rules,
  AdMob/FCM manifest meta-data, deep-link `<intent-filter
  android:autoVerify>` template.
- GitHub Actions CI: format → analyze → test → debug build on every PR.
- Unit tests for feature configs, helpers, and the action dispatcher.

### Changed
- Bumped Android Kotlin Gradle Plugin to 2.1.20 (was 1.9.22). Required
  by device_info_plus 12.x's Kotlin 2.x stdlib extensions; older KGP
  fails the build with unresolvable Kotlin standard-library symbols.
- Bumped `compileSdk` and `targetSdk` to 36. Required by
  webview_flutter_android's AAR metadata; the previous 34/34 produced
  a Gradle compatibility warning before the bump.
- Added Firebase BOM 33.7.0 + `com.google.firebase:firebase-messaging`
  (no `-ktx` suffix; deprecated in BOM 33.x). Brings
  FirebaseMessagingService onto the app's compile classpath so
  WebSightMessagingService resolves at build time.
- Added `com.google.guava:guava:33.0.0-android` to bring
  `com.google.common.util.concurrent.ListenableFuture` onto the
  compile classpath. CameraX's `ProcessCameraProvider.getInstance()`
  returns the type; without Guava on classpath KGP 2.x can't resolve
  it.
- Manifest `<queries>` element repositioned to be a sibling of
  `<application>` (was nested inside). AAPT2 silently merged it before
  but Play Console rejects nested placement.
- README rename-vs-configure ordering note now matches WHITELABEL: run
  `change_app_package_name` BEFORE `tool/configure.dart` (or re-run
  configure afterwards).
- `tool/configure.dart` regex anchors tightened: `gradleOp` now
  rewrites only `defaultConfig.applicationId` (not productFlavor ids);
  `manifestOp` now rewrites only the autoVerify intent-filter's host.
- `tool/init.dart` (wizard) now halts cleanly on subprocess failure.
  Previously a non-zero exit from `flutterfire configure` was logged
  as a warning and the wizard proceeded, leaving Firebase
  half-applied. Errors emit one line + tail of stderr instead of a
  Dart stack trace.
- `permissions_controller.dart` honors
  `notifications.post_notifications_permission` (was hardcoded on).
- `app_router.dart`: initial location resolved from `app.home_url` against
  the route table; parameterized routes (`/web/item/{id}`) implemented.
- `app_shell.dart`: AppBar actions, drawer, bottom tabs, and FAB are all
  driven from config; ad banners respect SafeArea per top/bottom.
- `webview_controller.dart`: re-enabled error reporting; classified
  connectivity errors as offline; user-agent modes (system / append /
  custom); CSS/JS injection on page finish; explicit external scheme
  handling.
- `js_bridge.dart`: stable error codes, runtime origin enforcement,
  JSON-encoded callback IDs, structured rejections.
- `assets/websight.js`: Promise contract returns `{code,message}` on
  reject; defensive `postMessage`.
- `helpers.dart`: extended icon map; `parseColor` accepts 3/6/8-char hex
  with safe fallback.
- `analysis_options.yaml`: strict casts/inference, prefer_single_quotes,
  unawaited_futures, always_use_package_imports, etc.

### Fixed
- File uploads (`<input type=file>`) no longer no-op. Replaced the
  empty `_onShowFileSelector` shim with a real `pickFiles`
  method-channel call.
- AppBar `webview.reload` now actually reloads the WebView (was an
  empty callback).
- Scanner: missing CAMERA runtime permission gate caused a black
  screen + indefinite Dart hang on Android 6+ devices that hadn't
  granted camera. Multi-barcode frames could fire the listener twice.
- `downloadBlob` ran on the UI thread, ANR-class hazard on multi-MB
  blobs; OOM risk on very large payloads.
- FCM notifications: tapping the second push delivered the first
  push's `route` extra (PendingIntent requestCode collision).
- Inbound `navigate:` accepted any string the page supplied. Now
  rejected unless the route exists in `flutter_ui.routes`.
- AppShell ad reload thrashed on every dependency change (rotation,
  theme switch). Now memoized to actual route transitions.
- FcmController stream listeners stacked across hot reloads in dev;
  on real teardown they outlived the controller. Now canceled in
  dispose.
- WebView injection chain (CSS / JS / bridge / interceptor) could
  fire after dispose if the user navigated fast. Now guarded.
- UmpConsent re-fetched the consent state from the network on every
  cold start. Skips when canRequestAds() already returns true.
- BillingController errors only debugPrinted; release builds had no
  visibility. Now stored as `lastError` + reported to Crashlytics.
- `parseColor` silently returned transparent on malformed input;
  now also debugPrints a one-line warning in dev.
- ConfigurableNativeScreen IAP tile read "0 product(s)" when billing
  was enabled but unconfigured; now reads "Enabled, no products
  configured".
- README fork-workflow note: `change_app_package_name` rewrites
  applicationId, so it must run BEFORE `tool/configure.dart`. Added
  an "Order matters" callout.
- Adaptive banner ad height now reflects the live device orientation.
  `AdsController._getAdSize` previously hard-coded `Orientation.portrait`
  when calling `AdSize.getAnchoredAdaptiveBannerAdSize`, producing a
  too-tall banner on landscape devices and after rotation. Now it reads
  `MediaQuery.of(context).orientation`; `app_shell.dart`'s existing
  `didChangeDependencies` hook reloads the banner on rotation so the
  size updates automatically.
- Gradle build broken on non-Windows machines: `settings.gradle.kts`
  hardcoded `C:/dev/flutter/...` path replaced with `local.properties`
  lookup.
- `app/build.gradle.kts` written in Groovy syntax inside a `.kts` file
  rewritten in proper Kotlin DSL with explicit dependencies.
- Empty `dependencies {}` block (CameraX / ML Kit / UMP / AppCompat) now
  populated; signing config no longer NPEs when `key.properties` is
  absent.
- Removed dead duplicate `MainActivity.kt` files
  (`com.app.myapp`, `com.example.myapp`).
- Removed redundant `WebBridge.kt` (functionally identical to
  `WebSightChromeClient.kt`).
- Removed dead `lib/bridge/method_channel_bridge.dart` (never imported).
- BillingController missing `_disposed` flag: a final purchase update
  arriving during stream cancellation could call `notifyListeners()`
  after super.dispose, throwing in release. Mirrored FcmController's
  pattern; `_iap` is now `late final` so unit tests don't trigger
  Android BillingClient registration.
- `yamlHostsOp` only replaced the FIRST entry under
  `restrict_to_hosts:` and `deep_links.hosts:`. Behavior unchanged for
  the common single-entry case, but `tool/configure.dart` now prints a
  NOTE listing how many extra entries existed so integrators can
  review them by hand.
- `_SplashOverlay` AnimatedSwitcher's dismissed branch had no key,
  letting it collide with sibling `SizedBox.shrink` instances and
  occasionally glitch the cross-fade. Added a distinct `ValueKey`.
- Doctor's deep-link host check no longer hard-fails when YAML host is
  the demo `flutter.dev` placeholder (was already tolerant of
  `YOUR_PRIMARY_HOST_HERE`). Lets `tool/doctor.dart` run cleanly in CI
  on a fresh fork before `tool/configure.dart` runs.

### Removed
- `GEMINI.md` (37KB AI-agent prompt unrelated to product).
- `webview_config.yaml.bak` and `webview_config.yaml.example` (the latter
  was identical to the live demo config).
- `lib/native_screens/{watchlist,portfolio,alerts,settings}_screen.dart` —
  hardcoded mock data ($12,345.67 portfolio balance, fabricated tickers,
  unwired settings toggles). Replaced by `ConfigurableNativeScreen`.

### Security
- Sanitized `google-services.json` — removed leaked `com.app.blokz` and
  `mx.blokz.blokz_mobile` Firebase clients along with the real API key.
  Ship only `google-services.json.example` plus a placeholder
  `google-services.json` to keep `flutter build` working.
- Tightened `file_paths.xml` (no longer expose entire external storage).
- Added `network_security_config.xml` (HTTPS-only base).
- Disabled `allowBackup` and `dataExtractionRules` by default.


[Unreleased]: https://github.com/blokzdev/websight/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/blokzdev/websight/releases/tag/v1.0.0
