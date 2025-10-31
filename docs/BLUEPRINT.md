# WebSight: Universal WebView App Shell

## Overview

WebSight is a production-ready, highly configurable Flutter-based application shell that transforms any modern website into a native mobile app for Android. It provides a robust and secure environment for web content while offering a seamless user experience with native UI components, deep integration with platform features, and monetization options.

## Features

- **Declarative Configuration**: The entire application behavior is controlled by a single `webview_config.yaml` file, allowing for easy customization without modifying the source code.
- **Hybrid UI**: Combine web content with a native Flutter UI layer, including a navigation drawer, bottom tabs, or a simple app bar.
- **Secure WebView**: The WebView is hardened with a host allowlist, deep link handling, and secure JavaScript bridging.
- **Native Bridge**: A secure JavaScript-to-native bridge (`window.WebSightBridge`) exposes device capabilities to the web application, such as camera access, barcode scanning, file uploads, and downloads.
- **Monetization**: Integrated support for Google Mobile Ads (AdMob) with User Messaging Platform (UMP) consent, including adaptive and collapsible banners.
- **In-App Updates**: Keep users on the latest version of the app with flexible in-app update prompts.
- **Analytics and Crash Reporting**: Built-in hooks for analytics and crash reporting to monitor app performance and stability.
- **Offline and Error Handling**: Gracefully handle network interruptions and page loading errors with configurable offline and error pages.
- **Route Registry**: Define a flexible routing system with both WebView-based and native Flutter screens.

## Architecture

WebSight follows a layered architecture, separating concerns and promoting code reusability and maintainability.

- **Presentation Layer**: The UI of the application, built with Flutter. This includes the main app shell, native screens, and the WebView widget.
- **Domain Layer**: The business logic of the application, including configuration parsing, validation, and routing.
- **Data Layer**: The data sources of the application, which in this case is primarily the `webview_config.yaml` file.
- **Platform Layer**: The native Android components that provide access to platform features, such as the barcode scanner and file downloader.

## Current Plan

The current development plan involves the following steps:

1.  **Project Scaffolding**: Create the basic project structure, including directories for configuration, UI shell, WebView, JavaScript bridge, ads, and native screens.
2.  **Configuration Loading**: Implement the logic to load and parse the `webview_config.yaml` file into strongly-typed Dart models.
3.  **Configuration Validation**: Create a validation and normalization engine to enforce the single-source-of-truth rules for the configuration.
4.  **UI Shell**: Build the main application shell with a configurable layout (drawer, bottom tabs, or top tabs).
5.  **Routing**: Implement a routing system using `go_router` that can handle both WebView and native screens.
6.  **WebView Implementation**: Create the WebView screen with a custom `WebViewController` to handle navigation, multiple windows, and deep links.
7.  **JavaScript Bridge**: Implement the Flutter side of the JavaScript bridge and the corresponding platform channel to communicate with the native Android code.
8.  **Native Android Components**: Develop the native Android components for barcode scanning, file uploads, and downloads.
9.  **Ads Integration**: Integrate the Google Mobile Ads SDK with UMP consent and support for adaptive and collapsible banners.
10. **In-App Updates and Analytics**: Add support for in-app updates and hooks for analytics and crash reporting.
11. **Native Screens**: Create the placeholder native screens for the watchlist, settings, portfolio, and alerts.
12. **JavaScript Helper**: Create the `assets/websight.js` file to be injected into the WebView.

This plan will be executed iteratively, with a focus on creating a robust and flexible foundation for the application.
