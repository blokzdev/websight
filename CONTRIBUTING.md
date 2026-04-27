# Contributing to WebSight

Thanks for your interest. This project is a small, opinionated template for
turning a website into an Android app. The contribution surface is
intentionally narrow: most customization happens in your fork's
`webview_config.yaml`, not in core code.

## Setup

```bash
flutter pub get
# Optional: regenerate .g.dart for webview_config.dart
dart run build_runner build --delete-conflicting-outputs
```

You'll need:
- Flutter stable (current minimum: see `pubspec.yaml` `environment.sdk`)
- JDK 17
- Android SDK with Build-Tools matching `compileSdk = 34`

## Branches

- `main` is production. Feature branches use the form
  `<area>/<short-description>` (`bridge/error-codes`,
  `shell/bottom-tabs`, etc.).
- Open PRs against `main`. CI runs format, analyze, test, and a debug build.

## Commit style

- Imperative mood ("Add splash overlay", not "Added").
- One concern per commit. Keep diffs reviewable.
- Reference roadmap phases in the body where relevant.

## Code style

- `flutter analyze` must pass with zero warnings (lints are tightened in
  `analysis_options.yaml`).
- `dart format` is enforced by CI; default 80 columns.
- Don't add comments that restate the code. Use comments to capture *why*
  (security invariants, platform quirks, non-obvious tradeoffs).
- Prefer extending `WebSightFeatures` (hand-rolled `fromMap`) over
  expanding the json_serializable model layer — it avoids forcing every
  contributor through `build_runner`.

## Tests

- Pure-Dart logic gets a unit test under `test/<area>/`.
- Don't pin tests to `flutter.dev`-style live URLs; use synthetic configs.
- Native (Kotlin) changes that touch `MainActivity` should be smoke-tested
  on a debug build before opening the PR.

## Security

- Never commit a real `google-services.json`, `key.properties`, or any
  AdMob app id you don't own. CI lints for the placeholder values.
- Bridge methods that touch the filesystem must scope writes to the app
  sandbox or `MediaStore` — never the SD card root.
- New JS bridge methods must respect `js_bridge.secure_origin_only` and
  return stable error codes (see `BridgeErrorCodes` in `js_bridge.dart`).

## Filing issues

Please include:
- Flutter version (`flutter --version`)
- Android device + API level
- Minimal `webview_config.yaml` reproducing the issue
- `flutter logs` excerpt
