pluginManagement {
    includeBuild("C:/dev/flutter/packages/flutter_tools/gradle")
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.google.gms.google-services") version "4.4.1" apply false
}

include(":app")
