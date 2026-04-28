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
  multidex, `compileSdk = 36`, `minSdk = 24`.

## Workflow: clone → ship

**Fast path (recommended):**

```bash
git clone <this-repo> my-app && cd my-app
flutter pub get
dart run tool/init.dart        # interactive wizard — rich TUI or plain prompts
```

The wizard walks identity / theme / disclaimer / features / splash;
writes `assets/webview_config.yaml`; runs the propagator; offers icons,
native splash, `flutterfire configure`, keystore generation, and a
smoke build. Re-runnable.

The condensed manual flow is below; the canonical end-to-end guide
(toolchain, identity, icons, splash, Firebase, AdMob, signing, Play
Console, trademark/ToS guidance) lives in
**[docs/WHITELABEL.md](./docs/WHITELABEL.md)**. Drop-in starter configs
live in [examples/](./examples/). Run `dart run tool/doctor.dart` any
time to survey project state.

### 1. Fork or clone

Each app you ship is an independent fork. Duplicate the `websight`
folder for each project. (Or use GitHub's "Use this template" button
once the repo has the template flag set.)

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Edit identity in **one** place

`assets/webview_config.yaml` is the single source of truth for app
identity. Set the `app:` block:

```yaml
app:
  name: "My Shop"
  host: "shop.example.com"
  home_url: "https://shop.example.com/"
  application_id: "com.yourcompany.shop"
  admob_app_id: "ca-app-pub-XXXXXXXXXX~YYYYYYYYYY"
  version: "1.0.0+1"
```

While you're here, set your routes, theme, allowlist, AdMob banner unit
ids (`ads.placements.*.ad_unit_id` — these are separate from the App ID
in `app.admob_app_id` and are **not** touched by `tool/configure.dart`,
since they come from the AdMob console, not from app identity), FCM
flags, splash, etc.

### 4. Propagate identity to Android/Gradle/manifest/strings/pubspec

```bash
dart run tool/configure.dart           # apply
dart run tool/configure.dart --dry-run # preview without writing
```

The script keeps these files in sync with the YAML:

- `android/app/build.gradle.kts` — `applicationId` + `namespace`
- `android/app/src/main/AndroidManifest.xml` — deep-link
  `<data android:host>` + AdMob `APPLICATION_ID` meta-data
- `android/app/src/main/res/values/strings.xml` — `app_name`
- `pubspec.yaml` — `name` (snake_case) + `version`
- `assets/webview_config.yaml` — `security.restrict_to_hosts` +
  `navigation.deep_links.hosts` propagated from `app.host` so you only
  edit one host

It is idempotent (re-run any time) and validates inputs (rejects empty
`application_id`, malformed reverse-DNS, AdMob unit-ID-shaped values).

### 5. (Optional) Move the Kotlin package directory to match

The script writes `applicationId` and `namespace`, but does **not** move
Kotlin source files. To rename the directory tree under
`android/app/src/main/kotlin/com/...` to match your new
`applicationId`, run:

```bash
dart run change_app_package_name:main com.yourcompany.shop
```

This is destructive (moves files). **Order matters**: run this AFTER
`tool/configure.dart`. Running them in the other order is fine for the
manifest and `strings.xml`, but `change_app_package_name` rewrites
`build.gradle.kts` `applicationId` to its argument, so anything you
configured via the YAML before would be overwritten. The general rule:
let `tool/configure.dart` be the last identity-touching step.

### 6. Wire Firebase

```bash
npm install -g firebase-tools         # if not already
dart pub global activate flutterfire_cli
flutterfire configure
```

This regenerates `android/app/google-services.json` and
`lib/firebase_options.dart` with your project's real values. The repo
ships placeholder versions so the project builds out of the box.

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

- `assets/webview_config.yaml` — **single source of truth** for both
  runtime (theme, routes, ads, FCM, splash, downloads, JS bridge,
  security) and build-time identity (app name, host, applicationId,
  AdMob App ID).
- `assets/websight.js` — bridge helper injected into every page.
- `assets/offline/index.html` — offline fallback page.
- `tool/configure.dart` — propagates the identity values from the
  YAML into Gradle, manifest, strings, pubspec. Re-run any time the
  YAML changes; it is idempotent.
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
