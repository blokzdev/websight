# WebSight: The Declarative WebView App Factory

**WebSight is a production-ready, highly configurable Flutter starter project that turns any modern website into a native Android app.**

Powered by a single `webview_config.yaml` file, WebSight acts as a declarative factory for building WebView-based apps. It provides a robust and secure shell that combines your web content with a native Flutter UI, monetization, and essential platform features, eliminating the need for custom native code for most use cases.

---

## Vision

The goal of WebSight is to be the fastest path from a web application to a polished, policy-compliant, and production-ready mobile app. It's designed for developers who want to leverage their existing web content while still offering users a first-class native experience, complete with features like barcode scanning, in-app updates, and native ads.

---

## Features

- **Declarative First**: The entire app—from theme and layout to feature flags and ad placements—is controlled by the `webview_config.yaml` file.
- **Hybrid UI Layer**: Seamlessly blend your web content with a native Flutter UI, including configurable navigation (Drawer, Bottom Tabs, Top Tabs), an AppBar, and custom native screens.
- **Hardened WebView Engine**: The WebView is secured with a strict host allowlist, secure handling of external links, popup blocking (`target="_blank"`), and robust error/offline state management.
- **Powerful JavaScript Bridge**: A secure bridge (`window.WebSightBridge`) exposes powerful native device features directly to your web app's JavaScript context:
  - Barcode Scanning (via CameraX and ML Kit)
  - Native Sharing
  - Device Information
  - File Downloads (including `blob:` URLs)
  - Inbound events to trigger native UI changes from the web (navigation, toasts).
- **Monetization & Compliance Ready**:
  - **Google Mobile Ads**: Built-in support for AdMob with configurable adaptive and collapsible banner placements.
  - **User Consent**: Integrated Google User Messaging Platform (UMP) flow to ensure GDPR and privacy compliance before any ads are shown.
- **Production-Ready Lifecycle**:
  - **In-App Updates**: Automatic prompts for flexible or immediate app updates from the Play Store.
  - **Analytics & Crash Reporting**: Deep integration with Firebase for automatic screen tracking, custom event logging, and crash reporting.
  - **Permissions Handling**: Graceful, automatic handling of runtime permissions like notifications on modern Android versions.
- **Polished UX**: Includes expected mobile features like Pull-to-Refresh and intelligent back-button navigation.

---

## Prerequisites: Setting Up Your Environment

Before you begin, ensure your development environment is ready.

### 1. Flutter SDK

Make sure you have the Flutter SDK installed. It is highly recommended to be on the latest stable version. You can check your version and upgrade by running:

```bash
# Check your current version
flutter --version

# Upgrade to the latest stable release
flutter upgrade
```

### 2. Firebase & FlutterFire CLIs

These command-line tools are essential for connecting your app to Firebase. If you haven't installed them, run the following commands:

```bash
# Install the core Firebase CLI (requires Node.js)
npm install -g firebase-tools

# Activate the FlutterFire CLI for Flutter-specific integration
dart pub global activate flutterfire_cli
```

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

### 2. Get Dependencies

Open your terminal at the root of the new project (`my_new_app/`) and run `flutter pub get` to download all the necessary packages.

```bash
flutter pub get
```

### 3. Set the Unique Application ID (CRITICAL)

This is the most important step to make your app unique for the Google Play Store.

- **Open the file**: `android/app/build.gradle.kts`
- **Find the `applicationId`**: Inside the `defaultConfig` block, you will find this line:
  ```kotlin
  applicationId = "com.example.websight"
  ```
- **Change it** to your own unique package name:
  ```kotlin
  applicationId = "com.yourcompany.yournewapp"
  ```
- **(Optional) Refactor Package Name**: If you want to change the Dart package name in your `pubspec.yaml` and native folders for consistency, a tool like `change_app_package_name` can be used, but changing the `applicationId` is the only mandatory step.

### 4. Connect to Firebase

Each app needs its own Firebase project. The `flutterfire configure` command handles this for you.

**Important "Don'ts":**
*   **Do NOT run `firebase init`**.
*   **Do NOT manually create `firebase_options.dart`**.

Run the command in your terminal at the project root:
```bash
flutterfire configure
```
Follow the prompts to connect to your Firebase project. The tool will use the `applicationId` you set in the previous step to register the app and generate the correct configuration files.

### 5. Define Your App in `webview_config.yaml`

This is where you bring your app to life. Rename `assets/webview_config.yaml.example` to `assets/webview_config.yaml` and customize it to match your vision.

### 6. Build and Release

- **Set Up Signing Keys**: Follow the official Flutter guide to [create an upload keystore](https://docs.flutter.dev/deployment/android#create-an-upload-keystore) and configure it in `android/app/build.gradle.kts` as instructed by the comments in that file.
- **Build the App Bundle**:
  ```bash
  flutter build appbundle --release
  ```
- The output is a standard Android App Bundle (`.aab`) ready for the Google Play Store.

---

## Troubleshooting

- **Hundreds of Errors & "uri_does_not_exist"**:
  - **Problem**: The project's dependencies are missing.
  - **Solution**: Run `flutter pub get` in your terminal at the project root.

- **"flutter.sdk not set in local.properties"**:
  - **Problem**: Your IDE (like Android Studio) opened the `android` subfolder instead of the project root.
  - **Solution**: Close the project. Go to `File` > `Open` and select the **root folder** of your Flutter project.

- **`flutter upgrade` Fails with "file is being used by another process"**:
  - **Problem**: Your IDE is locking the SDK files.
  - **Solution**: Completely close your IDE (`File` > `Exit`). Open a standalone terminal and run `flutter upgrade` from there.

---

## Project Structure

- **`assets/webview_config.yaml`**: The single source of truth for app configuration.
- **`lib/config/`**: Dart models that represent the YAML structure.
- **`lib/shell/`**: The Flutter UI layer (the App Shell and Router).
- **`lib/webview/`**: The core WebView implementation.
- **`lib/bridge/`**: The Flutter side of the JavaScript-to-native bridge.
- **`lib/lifecycle/`**: Controllers for managing app lifecycle events.
- **`lib/native_screens/`**: Placeholder native Flutter screens.
- **`android/app/src/main/kotlin/.../`**: Native Android (Kotlin) code for platform-specific features.
