# WebSight

**Declarative Android WebView app shell driven by a single
`webview_config.yaml`.**

Take any modern website and ship it to the Play Store with a hardened
native shell, JS bridge, AdMob + UMP consent, in-app updates, FCM,
in-app purchases, and analytics — all without writing platform code.

WebSight is **Android-only** (iOS is on the v1.x roadmap) and is
distributed as a fork-the-template starter, not a runtime.

---

## What you get

- **One YAML file**: theme, layout (drawer / bottom tabs / top tabs / none),
  app bar actions, drawer / FAB, deep links, host allowlist, ads,
  analytics, FCM, in-app updates, in-app purchases, splash, offline
  fallback, custom CSS / JS injection — all in
  `assets/webview_config.yaml`. Full schema reference at
  [`docs/internal/config-reference.yaml`](./docs/internal/config-reference.yaml).
- **Hardened WebView**: strict host allowlist, SSL block, file://
  navigation block, scheme handoff (tel/mailto/intent/geo/market) to
  Custom Tabs, configurable user agent (system / append / custom).
- **JS bridge** (`window.WebSightBridge`): scanBarcode, share,
  getDeviceInfo, downloadBlob, openExternal — all Promise-based with
  stable error codes. Origin-gated by config. See
  [`docs/bridge-api.md`](./docs/bridge-api.md).
- **Native pieces**: ML Kit barcode scanner (CameraX), file uploads,
  blob → MediaStore writes, FCM service with default channel, in-app
  updates (flexible / immediate), Crashlytics + Analytics auto-screen
  tracking.
- **Compliance**: Google UMP consent gate before
  `MobileAds.initialize()`; deny-by-default backups; HTTPS-only network
  security config; Android 13+ runtime notification permission.
- **Production gradle**: ProGuard/R8 rules, optional release signing,
  multidex, `compileSdk = 34`, `minSdk = 24`.

## Workflow: clone → ship

### 1. Fork or clone

Each app you ship is an independent fork. Duplicate the `websight`
folder for each project.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Set the application id (critical for Play Store)

Edit `android/app/build.gradle.kts`:

```kotlin
applicationId = "com.yourcompany.yourapp"
```

The `change_app_package_name` dev dependency can also rename the Kotlin
package if you want full consistency:

```bash
dart run change_app_package_name:main com.yourcompany.yourapp
```

### 4. Wire Firebase

```bash
npm install -g firebase-tools         # if not already
dart pub global activate flutterfire_cli
flutterfire configure
```

This regenerates `android/app/google-services.json` and
`lib/firebase_options.dart` with your project's real values. The repo
ships placeholder versions so the project builds out of the box.

### 5. Edit `assets/webview_config.yaml`

Set `app.host`, `app.home_url`, your routes, theme, allowlist, ads, FCM
flags, and so on. Keep the host in `app.host`,
`security.restrict_to_hosts`, and `navigation.deep_links.hosts` in sync.

### 6. (Optional) Update deep-link host

Edit `android/app/src/main/AndroidManifest.xml` — the `<intent-filter
android:autoVerify="true">` block has a `YOUR_PRIMARY_HOST` placeholder.
For full app links, host
`https://your-host/.well-known/assetlinks.json`.

### 7. Set up signing for release

Create `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

If `key.properties` is missing, release builds fall back to debug
signing — useful for quick smoke tests, but obviously not for the Play
Store.

### 8. (Optional) Customize the splash screen

WebSight has two splash layers:

- **Native pre-Flutter splash** — the first frame after process start,
  before the Dart VM is up. Configured under `flutter_native_splash:`
  in `pubspec.yaml`. Drop a logo at `assets/splash/logo.png`, point
  `image:` at it, and run:

  ```bash
  dart run flutter_native_splash:create
  ```

- **In-Flutter splash overlay** — shown by `_SplashOverlay` while the
  first WebView page loads. Configured under `splash:` in
  `assets/webview_config.yaml`:

  ```yaml
  splash:
    enabled: true
    timeout_ms: 1500
    fade_out_ms: 300
    image_asset: "assets/splash/logo.png"
    background_color: "#0B0B0C"
    tagline: "Loading…"
  ```

Both are optional. When neither is configured the app shows a brief
solid-color frame followed by the WebView's load progress.

### 9. Build

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`.

## Project structure

- `assets/webview_config.yaml` — single source of truth.
- `assets/websight.js` — bridge helper injected into every page.
- `assets/offline/index.html` — offline fallback page.
- `lib/config/` — typed config models (`webview_config.dart`,
  `feature_configs.dart`).
- `lib/shell/` — app shell, router, action dispatcher.
- `lib/webview/` — WebView controller + screen.
- `lib/bridge/` — Dart side of the JS bridge.
- `lib/lifecycle/` — analytics, updates, permissions, FCM, billing,
  rating.
- `lib/native_screens/` — placeholder native screens you customize.
- `android/app/src/main/kotlin/com/app/websight/` — `MainActivity` and
  platform plugins (scanner, UMP consent, file uploads, FCM service).

## Status

WebSight is mid-flight on a v1 hardening pass. See
[`docs/ROADMAP.md`](./docs/ROADMAP.md) for what is live, what is in
progress, and what is deferred.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md). PRs are welcome; the
maintained scope is the engine itself, not customer-specific
integrations.

## License

(Insert your chosen license here — MIT and Apache-2.0 are both common
for templates of this kind.)
