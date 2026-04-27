# Changelog

All notable changes to WebSight are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
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
