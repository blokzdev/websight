# WebSight Roadmap

This is the **honest** roadmap. It supersedes the earlier "all phases ✅"
status. The previous markings did not reflect the state of the code (the
native bridge had placeholder branches, several config keys were parsed and
discarded, the Gradle build was wired to a Windows-specific path, etc.).
The list below is what is actually in the repo and what is next.

---

## v1 (in progress)

### ✅ Foundation hardening (landed)

- Repo hygiene: removed leaked `blokz` Firebase clients from
  `google-services.json`; deleted dead `MainActivity` duplicates and the
  unrelated 37KB `GEMINI.md` AI-agent prompt; consolidated platform Kotlin
  under one canonical package; tightened lint rules
  (`analysis_options.yaml`).
- Gradle: rewrote `android/app/build.gradle.kts` in proper Kotlin DSL
  (was Groovy syntax inside a `.kts` file → would not compile); replaced
  Windows-only `C:/dev/flutter/...` path in `settings.gradle.kts` with
  `local.properties` lookup; added explicit dependency declarations
  (AppCompat, CameraX, ML Kit, UMP, Play Core, Browser Custom Tabs); safe
  optional signing config that falls back to debug signing when
  `key.properties` is missing.
- Android polish: ProGuard rules, network security config (HTTPS-only base
  with dev cleartext template), data extraction rules (no backups by
  default), tightened FileProvider paths, default notification channel
  meta-data, explicit `<queries>` for Android 11+ visibility, AdMob app id
  meta-data placeholder, deep-link `<intent-filter android:autoVerify>`
  template.

### ✅ Native bridge (landed)

- `MainActivity` method-channel handler now covers every contract method:
  `gatherConsent`, `scanBarcode` (launches `ScannerActivity`, routes the
  result via `onActivityResult`, `E_BUSY` guard against concurrent scans),
  `downloadBlob` (Base64 → `MediaStore.Downloads` on API 29+, legacy
  Downloads dir + `addCompletedDownload` on API ≤ 28), `registerHttpDownload`
  (DownloadManager enqueue), file uploads through `WebSightChromeClient`.
- Dart `JsBridge`: stable error codes (`E_PERMISSION`, `E_CANCELED`,
  `E_ARGS`, `E_INTERNAL`, `E_ORIGIN`, `E_UNSUPPORTED`); runtime origin
  enforcement (drops calls when `currentUrl().host` is not in
  `security.restrict_to_hosts`); JSON-encoded callback id interpolation
  (no raw quote injection); real `device_info_plus` values; structured
  error payloads.
- `assets/websight.js`: Promise contract returns `{code,message}` on reject;
  monotonic callback id; defensive `postMessage` when channel missing.
- `WebSightMessagingService` for FCM (silent payload pass-through, default
  channel creation, route-extra propagation for push-tap deep linking).

### ✅ Shell completeness (landed)

- `lib/config/feature_configs.dart`: hand-rolled feature configs for
  splash, offline HTML, custom user scripts, user agent modes, file uploads,
  downloads, billing, rating prompt, FAB, bottom tabs, drawer header/items,
  error pages. Avoids forcing a `build_runner` regenerate every time a new
  YAML key is added.
- `lib/shell/action_dispatcher.dart`: parses YAML action strings —
  `navigate:/path`, `webview.reload`, `webview.back`, `bridge.<method>`,
  `store.rate`, `noop` — used by AppBar / drawer / FAB / inbound events.
- `app_shell.dart`: AppBar actions, drawer (with header + items + footer),
  bottom navigation, and FAB are all driven from config.
- `app_router.dart`: initial location resolves from `app.home_url` against
  the route table; parameterized routes work end-to-end (YAML `/web/item/{id}`
  → go_router `/web/item/:id` with `{id}` substituted into the page URL).

### ✅ WebView features (landed)

- Splash overlay (`splash.enabled`, `splash.timeout_ms`).
- Offline overlay with retry (`behavior_overrides.error_pages`,
  `offline_local_html`).
- Custom CSS / JS injection on page-finish from
  `webview_settings.custom_user_scripts`.
- User-agent modes: `system` / `append` / `custom`.
- `WebsightWebViewController.loadOfflineFallback()` for the bundled
  `assets/offline/index.html`.

### ✅ Lifecycle controllers (landed)

- `permissions_controller.dart` finally honors
  `notifications.post_notifications_permission`.
- `fcm_controller.dart`: foreground listener, token refresh stream,
  cold-start `getInitialMessage`. Initializes only when
  `notifications.fcm_enabled` is true.
- `billing_controller.dart`: `in_app_purchase` wrapper around
  `billing.product_ids` (refresh / buy / restore / purchase stream).
- `rating_controller.dart`: launch counter via `shared_preferences`,
  fires `in_app_review.requestReview()` once `rating_prompt.after_launches`
  is reached.

### ✅ Tests + CI (landed)

- Unit tests for `feature_configs.dart`, `helpers.dart`, and
  `action_dispatcher.dart`.
- GitHub Actions workflow runs format check, `flutter analyze`,
  `flutter test --coverage`, and a debug Android build on every PR.

### ✅ Native screens (landed)

- Replaced four hardcoded native screen stubs (which shipped with mock
  data: `$12,345.67`, fabricated ticker rows, unwired settings toggles)
  with `ConfigurableNativeScreen`. Settings variant reads
  `WebSightConfig` / `WebSightFeatures` via Provider and shows the real
  app identity, theme, analytics flags, FCM token, and IAP product
  count. Privacy / Terms / About routes are surfaced automatically when
  present in the route table. Other `/native/*` routes render a clearly
  labeled placeholder with the route path so it's obvious where to plug
  in real screens.

### 🟡 Remaining for v1

- **Server-side IAP receipt validation reference**: not in scope for v1.
  Documented as integrator responsibility; receipts arrive in
  `BillingController.purchases`.
- **HTTPS DownloadListener**: today the Dart layer can call
  `registerHttpDownload` over the method channel, but the WebView itself
  doesn't auto-detect download links. Workaround: the integrator's web
  page calls `WebSightBridge.downloadBlob(...)`; full auto-detection is a
  v1.1 item (it requires a fork or a DOM content script).
- **Configurable splash drawable**: today's splash is a centered
  `CircularProgressIndicator`; v1.x will support a configurable image.
- **Honest README rewrite**: capture the new state, drop the overclaims.
- **`CHANGELOG.md` entry for v1.0**.

---

## v1.x

- iOS support (WKWebView shell, ATT consent, App Store metadata, signing).
- Single-binary remote-config variant (signed config download with TOFU + rotation).
- CLI scaffolder: `dart run websight new --config foo.yaml` produces a
  ready-to-build project.
- Server-side IAP validation reference impl (Cloud Functions + Play
  Developer API).
- WebView download auto-detection.

## v2

- Material You dynamic theming.
- Interstitial / rewarded ads.
- Expanded JS bridge: biometric auth, geolocation, contacts, haptics.
- AI contextual chat (Gemini API): page-aware in-app assistant.
- AI app factory: agent that scaffolds a WebSight project from a URL.

---

## How to track progress

Each section above maps to commits on the `claude/project-review-v1-roadmap-Wi8H8`
branch. The internal plan lives at `/root/.claude/plans/` (developer
machine only) and at `docs/internal/config-reference.yaml` for the
canonical YAML schema.
