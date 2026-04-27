# Changelog

All notable changes to WebSight are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
