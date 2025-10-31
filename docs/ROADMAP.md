# WebSight Development Roadmap

This document outlines the development plan for WebSight, a universal WebView app shell. It tracks progress across different phases, from the core foundation to production-ready features.

---

## Phase 1: Core Foundation & Configuration

**Status: ✅ Complete**

This phase focused on setting up the project structure, defining the core architecture, and implementing the configuration loading and validation system.

- [x] **Project Scaffolding**: Create the initial Flutter project structure.
- [x] **Dependency Setup**: Add all necessary dependencies to `pubspec.yaml`.
- [x] **Initial Blueprint**: Create `docs/BLUEPRINT.md` outlining the app's vision and architecture.
- [x] **Configuration Models**: Define Dart models for `webview_config.yaml` using `json_serializable`.
- [x] **Config Loader & Validator**: Implement the logic to load, parse, validate, and normalize the YAML configuration at startup.
- [x] **Initial File Stubs**: Create placeholder files for all major components.

---

## Phase 2: UI Shell & Routing

**Status: ✅ Complete**

This phase focused on building the visual shell of the application, including navigation, layout, and theming, all driven by the `webview_config.yaml` file.

- [x] **App Router Implementation**:
  - [x] Flesh out `AppRouter` using `go_router`'s `ShellRoute`.
  - [x] Ensure correct routing to both WebView (`/web/*`) and native (`/native/*`) screens.
- [x] **App Shell Layouts**:
  - [x] Implement the `AppShell` to dynamically build the UI based on `layout.style`.
  - [x] Support `"drawer"`, `"bottom_tabs"`, `"top_tabs"`, and `"none"` layouts.
- [x] **Dynamic Themeing**:
  - [x] Apply theme settings from the config (brightness, primary color, Material 3).
  - [x] Load custom fonts using `google_fonts`.
- [x] **Dynamic AppBar**:
  - [x] Control AppBar visibility and build actions from the config.

---

## Phase 3: WebView Engine Enhancement

**Status: ✅ Complete**

This phase enhanced the core WebView functionality, focusing on navigation control, platform-specific features, and robust error handling.

- [x] **Advanced Navigation Control**:
  - [x] Solidify `NavigationDelegate` logic to enforce host restrictions.
  - [x] Handle external links and custom schemes (`tel:`, `mailto:`, etc.).
  - [x] Intercept `onCreateWindow` to handle popups.
- [x] **Android WebView Features**:
  - [x] **File Uploads**: Implement `WebChromeClient.onShowFileChooser`.
  - [x] **HTTP/S Downloads**: Implement a `DownloadListener` using Android's `DownloadManager`.
- [x] **Error & State Handling**:
  - [x] Implement offline/error page logic.
  - [x] Implement configurable back button behavior (`webview.goBack()` vs. app exit).
  - [x] Block insecure navigations and SSL errors.
- [x] **Pull to Refresh**: Implement `RefreshIndicator` based on per-route config.

---

## Phase 4: JavaScript Bridge & Native Integration

**Status: ✅ Complete**

This phase implemented the two-way communication channel between the web content and the native Flutter/Android layers.

- [x] **JavaScript Bridge**:
  - [x] Finalize the `assets/websight.js` helper for a clean, `Promise`-based API.
  - [x] Implement Flutter-side message handlers for all configured methods and inbound events.
  - [x] Enforce `security.secure_bridge_origin_only` from the config.
- [x] **Native Method Channel Implementation**:
  - [x] **Barcode Scanning**: Implement `ScannerActivity` with CameraX and ML Kit.
  - [x] **Blob Downloads**: Implement Base64 decoding and file saving via `MediaStore`.
  - [x] **Utility Methods**: Implement native handlers for `share`, `getDeviceInfo`, and `openExternal`.

---

## Phase 5: Monetization & Compliance

**Status: ✅ Complete**

This phase integrated monetization through ads and ensured compliance with platform requirements like user consent.

- [x] **User Messaging Platform (UMP) Consent**:
  - [x] Implement the full UMP flow in `UmpConsent.kt`.
  - [x] Ensure `MobileAds.initialize()` is called only after a valid consent status is obtained.
- [x] **AdMob Integration**:
  - [x] Implement logic to display banners based on global and per-route configurations.
  - [x] Support `"adaptive"` banner types.
  - [x] Support `"collapsible"` banner types.

---

## Phase 6: App Lifecycle & Polish

**Status: ✅ Complete**

This phase focused on improving the overall user experience with lifecycle features, analytics, and building out the native UI sections.

- [x] **In-App Updates**:
  - [x] Integrate the `in_app_update` package.
  - [x] Implement both `"flexible"` and `"immediate"` update flows based on the config.
- [x] **Analytics & Crash Reporting**:
  - [x] Fully integrate Firebase Analytics and Firebase Crashlytics.
  - [x] Add hooks to log key events (e.g., route changes).
- [x] **Notifications**:
  - [x] Implement the runtime permission request for `POST_NOTIFICATIONS` on Android 13+.
- [x] **Native Screens**:
  - [x] Build out the UI for the placeholder native screens (`Watchlist`, `Settings`, etc.).

---

## Phase 7: Documentation & Release Preparation

**Status: ✅ Complete**

This phase prepares the project for public consumption or handover, with a focus on clear documentation and release readiness.

- [x] **Comprehensive `README.md`**: Write a detailed README with project overview, features, setup instructions, and configuration guide.
- [x] **Example Configuration**: Create a heavily commented `webview_config.yaml.example` file that explains every available option.
- [x] **Release Build**:
  - [x] Configure Android signing keys for a production build.
  - [x] Set up ProGuard/R8 rules for code shrinking.
  - [x] Perform a final round of testing on a release build.

---

## Future Builds (v2 and Beyond)

This section outlines potential features and enhancements for future versions of WebSight, post-launch.

- **Advanced Flutter UI**:
  - **Parameterized Routes**: Implement logic to handle dynamic parameters in web routes (e.g., `/item/{id}`).
  - **Granular Navigation**: Allow `drawer` and `bottom_tabs` items to be configured independently of `routes`, with support for headers, dividers, and action-triggers (e.g., `bridge.scanBarcode`).
  - **Material You Theming**: Add support for dynamic color theming based on the user's wallpaper.
- **Firebase & Notifications**:
  - **Firebase Cloud Messaging (FCM)**: Add a full setup for receiving and handling push notifications and bridging them to the JavaScript context.
- **Monetization & Engagement**:
  - **Advanced Ads**: Implement `interstitial` and `rewarded` ad formats.
  - **In-App Purchases**: Integrate a billing package to manage subscriptions and one-time products.
  - **Rating Prompt**: Integrate the `in_app_review` package to intelligently ask users for a review.
- **AI-Powered Features**:
  - **AI-Powered Contextual Chat (Frontend, Users)**: Integrate the Gemini API to provide an in-app chat assistant that is "context-aware" of the current URL, page content, or a screenshot.
  - **AI-Powered App Factory (Backend, Developers)**: Create a command-line or chat-based tool that uses an AI agent to automate the entire process of creating a new WebSight app.
- **Enhanced WebView & Offline Experience**:
  - **Splash Screen**: Implement a configurable splash screen that can be shown for a set duration.
  - **Offline Content**: Implement logic to load a local HTML page from assets as a fallback when the user is offline.
  - **Enhanced Caching**: Implement a more sophisticated caching strategy for web assets.
- **Expanded JavaScript Bridge**:
  - Add more native APIs to the bridge, such as biometric authentication (`local_auth`), geolocation, or contacts.
