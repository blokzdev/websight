# WebSight: The Declarative WebView App Factory

**WebSight is a production-ready, highly configurable Flutter starter project that turns any modern website into a native Android app.**

Powered by a single `webview_config.yaml` file, WebSight acts as a declarative factory for building WebView-based apps. It provides a robust and secure shell that combines your web content with a native Flutter UI, monetization, and essential platform features, eliminating the need for custom native code for most use cases.

## Vision

The goal of WebSight is to be the fastest path from a web application to a polished, policy-compliant, and production-ready mobile app. It's designed for developers who want to leverage their existing web content while still offering users a first-class native experience, complete with features like barcode scanning, in-app purchases, and push notifications.

## Features

- **Declarative First**: The entire app—from theme and layout to feature flags and ad placements—is controlled by the `webview_config.yaml` file.
- **Hybrid UI Layer**: Seamlessly blend your web content with a native Flutter UI, including configurable navigation (Drawer, Bottom Tabs), an AppBar, and custom native screens.
- **Hardened WebView Engine**: The WebView is secured with a strict host allowlist, secure handling of external links, popup blocking, and robust error/offline state management.
- **Powerful JavaScript Bridge**: A secure bridge (`window.WebSightBridge`) exposes powerful native device features directly to your web app's JavaScript context:
  - Barcode Scanning (via CameraX and ML Kit)
  - Native Sharing
  - Device Information
  - File Downloads (including `blob:` URLs)
  - Inbound events to trigger native UI changes from the web.
- **Monetization & Compliance Ready**:
  - **Google Mobile Ads**: Built-in support for AdMob with configurable adaptive and collapsible banner placements.
  - **User Consent**: Integrated Google User Messaging Platform (UMP) flow to ensure GDPR and privacy compliance before any ads are shown.
- **Production-Ready Lifecycle**:
  - **In-App Updates**: Automatic prompts for flexible or immediate app updates.
  - **Analytics & Crashlytics**: Deep integration with Firebase for automatic screen tracking, custom event logging, and crash reporting.
  - **Permissions Handling**: Graceful, automatic handling of runtime permissions like notifications on modern Android versions.

---

## The WebSight Workflow: Building Your App

This project is a **template**. To create a new app, you follow this workflow:

### 1. Create a New Project Copy

Duplicate the entire `websight` project folder to create a new, independent project for your app.

```
/my_apps/
  ├── websight_starter/
  └── my_new_app/      <-- A fresh copy
```

### 2. Rename the Project (Recommended)

To ensure your project is properly organized and unique, you should update the Flutter package name and the native application ID. A simple find-and-replace is **not recommended** as it can break native project files.

The safest method is to use the `change_app_package_name` tool.

**a. Add the Tool:**
Open your terminal at the root of your new project (`my_new_app/`) and run:
```bash
flutter pub add dev:change_app_package_name
```

**b. Run the Tool:**
Execute the following command, replacing `"com.mycompany.mynewapp"` with your desired package name. This will automatically update all necessary files in Android and iOS.
```bash
flutter pub run change_app_package_name:main com.mycompany.mynewapp
```

This command intelligently renames everything that needs to be changed, including the native application ID, `pubspec.yaml` name, and native folder structures.

### 3. Connect to Firebase

Each app needs its own Firebase project for analytics and crash reporting.

- In your terminal at the project root, run the FlutterFire CLI command:
  ```bash
  flutterfire configure
  ```
- Follow the prompts to either create a new Firebase project or connect to an existing one. This will automatically generate the required `lib/firebase_options.dart` and `android/app/google-services.json` files.

### 4. Define Your App in `webview_config.yaml`

This is where you bring your app to life. Open `assets/webview_config.yaml` and customize it:

- **`app`**: Set your `host` and `home_url`.
- **`flutter_ui`**: Define your app's `theme` (colors, fonts) and `layout` (drawer, tabs, AppBar actions).
- **`routes`**: Map out the navigation for your app.
- **`ads`**: Enable ads and provide your AdMob `ad_unit_id` for each placement.
- **Features**: Toggle other features like `in_app_updates` and `js_bridge`.

### 5. Build and Release

Once configured, you are ready to build your production app.

- **Set Up Signing Keys**: Follow the official Flutter guide to [create an upload keystore](https://docs.flutter.dev/deployment/android#create-an-upload-keystore) and reference it in `android/app/build.gradle.kts`.
- **Build the App Bundle**:
  ```bash
  flutter build appbundle --release
  ```
- The output is a standard Android App Bundle (`.aab`) ready for the Google Play Store.

---

## Project Structure

- **`assets/webview_config.yaml`**: The single source of truth for app configuration.
- **`lib/config/`**: Dart models that represent the YAML structure.
- **`lib/shell/`**: The Flutter UI layer (the App Shell and Router).
- **`lib/webview/`**: The core WebView implementation.
- **`lib/bridge/`**: The Flutter side of the JavaScript-to-native bridge.
- **`lib/lifecycle/`**: Controllers for managing app lifecycle events like updates and analytics.
- **`lib/native_screens/`**: Placeholder native Flutter screens.
- **`android/app/src/main/kotlin/.../`**: Native Android (Kotlin) code for platform-specific features.
