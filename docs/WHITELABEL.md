# Whitelabel Guide

How to take this template, point it at any web app's domain, and ship a
signed Android App Bundle to Google Play. End-to-end recipe;
domain-agnostic.

> **Quick reference:** if you've forked a WebSight app before, the
> condensed cheat-sheet is at the bottom of this doc.

---

## 1. Decide your model

| Scenario | What it looks like | Special requirements |
|---|---|---|
| **Personal / dev / educational** | Sideload onto your own devices, never publish. | None beyond toolchain. |
| **Internal distribution** | Play Console internal-test or org-managed install. | Standard Play account; no listing. |
| **Public listing of your own site** | The site is yours; you have trademark + ToS authority. | Privacy policy, Data Safety form. |
| **Public listing of a third-party site** | You are wrapping someone else's site (e.g. blockchair.com). | Trademark + ToS review **before any code work**. See §10. |

The rest of this guide assumes the public-listing path; downstream
scenarios are strict subsets.

---

## 2. Toolchain prerequisites (one-time)

- **Flutter** stable, matching `pubspec.yaml`'s `environment.sdk`
  (currently `>=3.2.3 <4.0.0`). `flutter doctor` should be green for
  the Android toolchain.
- **JDK 17.** Android Gradle Plugin 8.x requires it.
- **Android SDK** with Build-Tools 34. Android Studio installs them; or
  `sdkmanager "build-tools;34.0.0" "platforms;android-34"`.
- **Node.js** for `firebase-tools` (only if you use Firebase).
- **`keytool`** (ships with the JDK) for the upload keystore.

---

## 3. Per-fork identity

Every fork is an independent app. The single source of truth for
identity is `assets/webview_config.yaml` `app:`:

```yaml
app:
  name: "Your App Name"
  host: "yourdomain.com"
  home_url: "https://yourdomain.com/"
  application_id: "com.yourcompany.yourapp"   # reverse-DNS, lowercase
  admob_app_id: "ca-app-pub-XXXXXXXXXX~YYYYYYYYYY"  # or omit, set ads.enabled: false
  version: "1.0.0+1"
```

Then run the propagator:

```bash
dart run tool/configure.dart --dry-run   # preview
dart run tool/configure.dart             # apply
```

This rewrites:

- `android/app/build.gradle.kts` — `applicationId` + `namespace`
- `android/app/src/main/AndroidManifest.xml` — deep-link host + AdMob
  `APPLICATION_ID` meta-data
- `android/app/src/main/res/values/strings.xml` — `app_name`
- `pubspec.yaml` — `name` (snake_case) + `version`
- `assets/webview_config.yaml` — `security.restrict_to_hosts` and
  `navigation.deep_links.hosts` propagated from `app.host`

The script is idempotent. Re-run any time the YAML changes.

> **Order matters.** If you also use `change_app_package_name` to
> move the Kotlin source tree, run it BEFORE `tool/configure.dart`
> — otherwise the package-rename tool overwrites the Gradle
> `applicationId` you just configured.

For a ready-to-go starter, see
[`examples/blockchair.yaml`](../examples/blockchair.yaml).

---

## 4. App icon

Android needs **legacy raster icons** (5 densities) plus an **adaptive
icon** (foreground + background) plus an optional **monochrome glyph**
(themed icons on Android 13+). The template ships placeholders for all
of them, plus `flutter_launcher_icons` as a dev dep.

### Recommended workflow

1. Generate the source images. Two good options:
   - **[icon.kitchen](https://icon.kitchen/)** — visual editor; paste a
     logo or pick a glyph + colors. Click "Download" → "Flutter". The
     ZIP gives you `icon.png` (1024×1024, transparent background) and
     a recommended background color.
   - **Hand-craft** — any 1024×1024 PNG with a transparent background
     works for the foreground. Pick a brand background color in hex.
2. Drop the foreground PNG at `assets/launcher/icon.png` (the path the
   pubspec block expects). Optional separate monochrome glyph at
   `assets/launcher/icon_monochrome.png`.
3. Edit `pubspec.yaml`'s `flutter_launcher_icons:` block:
   ```yaml
   flutter_launcher_icons:
     android: "ic_launcher"
     ios: false
     image_path: "assets/launcher/icon.png"
     adaptive_icon_background: "#0B0B0C"
     adaptive_icon_foreground: "assets/launcher/icon.png"
     adaptive_icon_monochrome: "assets/launcher/icon_monochrome.png"  # optional
     min_sdk_android: 24
   ```
4. Regenerate:
   ```bash
   dart run flutter_launcher_icons
   ```
   This rewrites `android/app/src/main/res/mipmap-*/ic_launcher.png`
   plus the adaptive XML in `mipmap-anydpi-v26/`.

The default placeholder ships a centered "W" mark on `#0B0B0C`. Replace
it before publishing — the Play Store will accept it but it's the
template's mark, not yours.

---

## 5. Splash screen

WebSight has two splash layers:

- **Native pre-Flutter splash** (the very first frame, before Dart
  starts). Configured via `flutter_native_splash` in `pubspec.yaml`.
- **In-Flutter splash overlay** (shown while the first WebView page
  loads). Configured via `splash:` in `assets/webview_config.yaml`.

### Native splash

```yaml
# pubspec.yaml
flutter_native_splash:
  color: "#0B0B0C"
  image: assets/splash/logo.png
  android_12:
    color: "#0B0B0C"
    image: assets/splash/logo.png
  fullscreen: false
  android: true
  ios: false
```

Drop `assets/splash/logo.png` in (you can reuse the launcher icon),
then:

```bash
dart run flutter_native_splash:create
```

### In-Flutter splash

```yaml
# assets/webview_config.yaml
splash:
  enabled: true
  timeout_ms: 1500
  fade_out_ms: 300
  image_asset: "assets/splash/logo.png"
  background_color: "#0B0B0C"
  tagline: "Loading…"
```

Both layers are optional. If you skip them, the user sees a brief
solid-color frame followed by the WebView's load progress.

---

## 6. External services

### 6a. Firebase (required for Analytics / Crashlytics / FCM)

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
flutterfire configure
```

Pick (or create) the Firebase project, accept the `applicationId` you
set in step 3. This regenerates:

- `android/app/google-services.json`
- `lib/firebase_options.dart`

The repo ships placeholder versions of both so a fresh clone builds
out of the box; `flutterfire configure` overwrites them with your real
values.

In the Firebase console:

- **Analytics** — auto-enabled. The SDK starts when
  `analytics_crash.analytics: true` in YAML.
- **Crashlytics** — same; enable the product in the console.
- **Cloud Messaging (FCM)** — only if you want push. Otherwise leave
  `notifications.fcm_enabled: false`.

### 6b. AdMob (optional)

If you don't want ads, set `ads.enabled: false` and skip this section.

1. https://apps.admob.com → "Add App", select Android, link to your
   Firebase app.
2. Copy the App ID (`ca-app-pub-...~...`) into `app.admob_app_id`.
3. Create a Banner ad unit. Copy the Unit ID (`ca-app-pub-.../...`)
   into `ads.placements.global_banner.ad_unit_id` and any
   `route_placements.*.ad_unit_id` you keep.
4. **Re-run `dart run tool/configure.dart`** to push the App ID into
   the manifest.
5. Add your dev devices to AdMob → Test devices so you don't generate
   impressions during development.

The first time the app runs with ads enabled, the **UMP consent flow**
runs before `MobileAds.initialize()`. Consent state is cached, so
subsequent launches skip the network round-trip.

### 6c. In-app purchases (optional)

Set `billing.inapp_enabled: true` and list your `product_ids:` in YAML.
Products themselves are configured in the Play Console under
"Monetize → Products". License-test via internal testers; receipts
arrive in `BillingController.purchases`. **Receipt validation is your
backend's responsibility** — v1 ships client-only.

---

## 7. Signing

```bash
keytool -genkey -v \
  -keystore upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Move the keystore somewhere outside your repo (the home directory is
fine), then create `android/key.properties` (gitignored):

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```

If `key.properties` is missing, release builds fall back to debug
signing — useful for early smoke tests, but **not** for the Play
Store.

---

## 8. Build + verify

```bash
# Smoke run on a connected device:
flutter run -d <device>

# Release AAB:
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab

# Convert AAB -> APKs and install for a final verification:
bundletool build-apks --bundle=app-release.aab --output=app-release.apks \
  --connected-device
bundletool install-apks --apks=app-release.apks
```

Smoke checklist (run through each on real hardware):

- [ ] App icon shows correctly on launcher (and themed-icon shape on
      Android 13+).
- [ ] Native splash → in-Flutter splash → WebView transition is
      smooth.
- [ ] Disclaimer dialog (if `legal.unofficial_disclaimer.enabled`)
      shows on first launch; accept once → never re-prompts on the
      same body text.
- [ ] WebView loads your home_url; pull-to-refresh works.
- [ ] AppBar refresh icon reloads the WebView.
- [ ] Drawer / bottom-tabs / native settings page all render.
- [ ] External links route to Custom Tabs.
- [ ] Airplane mode → offline overlay with retry.
- [ ] If ads enabled: UMP consent on first run; banner loads.
- [ ] If file uploads expected: `<input type="file">` opens the system
      picker and the URI flows back.

---

## 9. Play Console

1. **Create the listing.** Internal testing track first.
2. **Privacy policy URL** is required. Cover at minimum:
   - WebView cookie storage (sandboxed per-app, separate from system
     Chrome).
   - Firebase Analytics + Crashlytics + FCM (if used).
   - AdMob + UMP (if used).
   - In-app purchases (if used).
3. **Data Safety form.** Declare what each enabled SDK collects.
   Common to this template: device identifiers (Crashlytics, AdMob),
   approximate location (AdMob), purchase history (IAP).
4. **App content questionnaire.** Honestly answer the ad disclosure,
   target audience, and crypto/finance disclosures (the last is
   relevant for blockchain-adjacent wrappers — Play has a specific
   policy section).
5. **Upload the AAB.** Internal track first; gather a few testers'
   feedback; promote to closed → open → production once stable.

App-Links auto-verification (so links like `https://yoursite/path`
open the app without the chooser) requires hosting
`https://yoursite/.well-known/assetlinks.json`. **You can only do this
on a domain you control.** When wrapping a third-party site, omit the
auto-verify path; links will still open the app via the "Open with"
picker.

---

## 10. Trademark, ToS, and Play policy

Read this section before you write a single line of code if you are
wrapping a site you don't own.

### Trademark

Names, logos, and icons that resemble the source site's brand can be
treated as **impersonation** by Play and as **trademark
infringement** by the rights holder. Two safe paths:

- **Authorization.** Get written permission from the operator. Not
  always realistic; worth asking when the relationship is friendly.
- **Distinct branding.** Pick a name that is clearly your own
  (e.g. "CryptoLens", "Explorer Suite", "YourBrand for X"). A
  "Powered by X" attribution in the listing description is fine; do
  not include the source's wordmark or logo in the launcher icon.

### Terms of Service / robots policy

Most public sites' ToS allow viewing in any user agent, but some
explicitly prohibit re-wrapping or scraping. Read
`https://yourdomain.com/terms` (and `robots.txt`) and confirm:

- WebView access is allowed (most sites: yes).
- You're not stripping or replacing ads (we don't — the wrapped page
  renders unchanged).
- You're not scraping — WebSight does not. The bridge layer does not
  exfiltrate page content.

### Play Store financial-services disclosures

Apps that surface blockchain or cryptocurrency content fall under
Play's Financial Services policy. Listing descriptions for these
typically need to include:

- "Informational only — no custody, trading, or financial advice."
- A working privacy policy URL.
- A working support contact (email or web).
- Honest answers in the App Content → Restricted Content section.

This is not legal advice; consult a lawyer if your app handles funds
or claims any kind of advisory role.

### In-app disclaimer

WebSight ships an opt-in first-launch disclaimer dialog
(`legal.unofficial_disclaimer.enabled: true`). Strongly recommended
when wrapping a site you don't own. The acceptance is keyed on a
hash of the body text, so editing the disclaimer re-prompts users on
next launch.

```yaml
legal:
  unofficial_disclaimer:
    enabled: true
    title: "Unofficial app"
    body: |
      This app is an unofficial WebView wrapper around <site>.
      It is not affiliated with or endorsed by <operator>.
      ...
    accept_label: "I understand"
    decline_label: "Exit"
    require_accept: true
```

---

## Cheat sheet

```bash
# 1. Identity
$EDITOR assets/webview_config.yaml          # set app: block
dart run tool/configure.dart                # propagate

# 2. (Optional) move Kotlin package to match applicationId
dart run change_app_package_name:main com.yourcompany.yourapp

# 3. Icons + splash
$EDITOR pubspec.yaml                        # flutter_launcher_icons + flutter_native_splash blocks
dart run flutter_launcher_icons
dart run flutter_native_splash:create

# 4. Firebase
flutterfire configure

# 5. (If ads) AdMob — paste IDs into YAML, re-run configure
dart run tool/configure.dart

# 6. Signing
keytool -genkey -v -keystore upload-keystore.jks ...
$EDITOR android/key.properties

# 7. Build
flutter build appbundle --release
```

If something breaks during `flutter analyze` / `flutter test` /
`flutter build`, paste the output and the maintainers (or your AI
co-pilot) can usually point at the line in seconds.
