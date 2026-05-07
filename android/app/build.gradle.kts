import java.util.Properties
import java.io.FileInputStream
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties().apply {
    val keystoreFile = rootProject.file("key.properties")
    if (keystoreFile.exists()) {
        FileInputStream(keystoreFile).use { load(it) }
    }
}

android {
    namespace = "com.app.websight"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // CRITICAL: change this to your unique application id before publishing.
        applicationId = "com.app.websight"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Falls back to debug signing if key.properties is missing so developers can
            // test release builds without a production keystore. Replace before shipping.
            signingConfig = if (keystoreProperties.isNotEmpty()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/DEPENDENCIES",
                "/META-INF/LICENSE",
                "/META-INF/LICENSE.txt",
                "/META-INF/NOTICE",
                "/META-INF/NOTICE.txt"
            )
        }
    }
}

// Kotlin Gradle Plugin's modern DSL. Replaces the legacy
// `kotlinOptions { jvmTarget = "17" }` block (deprecated in Kotlin 2.0,
// hard error from Kotlin 2.3 onward — see https://kotl.in/u1r8ln).
// Works on KGP 1.9+, so this stays compatible with both the current
// 2.1.20 and the dependabot-proposed 2.3.21 bump.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // AndroidX core libraries
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")
    implementation("androidx.activity:activity-ktx:1.9.2")
    implementation("com.google.android.material:material:1.12.0")

    // CameraX (used by ScannerActivity). Pinned to 1.5.1 to match what the
    // camera_android_camerax Flutter plugin pulls transitively; Gradle would
    // resolve to the higher version anyway, but pinning matches keeps the
    // AAR-metadata check happy.
    implementation("androidx.camera:camera-core:1.5.1")
    implementation("androidx.camera:camera-camera2:1.5.1")
    implementation("androidx.camera:camera-lifecycle:1.5.1")
    implementation("androidx.camera:camera-view:1.5.1")

    // Guava brings `com.google.common.util.concurrent.ListenableFuture`,
    // which `ProcessCameraProvider.getInstance()` returns. Without it on
    // the app's compile classpath, KGP 2.x can't access the type and every
    // call on the returned future ("unbindAll", "bindToLifecycle",
    // "addListener") fails to resolve.
    implementation("com.google.guava:guava:33.0.0-android")

    // ML Kit barcode scanning (bundled model)
    implementation("com.google.mlkit:barcode-scanning:17.3.0")

    // User Messaging Platform (consent)
    implementation("com.google.android.ump:user-messaging-platform:3.0.0")

    // Play services for in-app updates and integrity
    implementation("com.google.android.play:app-update:2.1.0")
    implementation("com.google.android.play:app-update-ktx:2.1.0")
    implementation("com.google.android.play:integrity:1.4.0")

    // FileProvider, browser custom tabs
    implementation("androidx.browser:browser:1.10.0")

    // Firebase Messaging (used directly by WebSightMessagingService).
    // The firebase_messaging Flutter plugin uses `implementation` for its
    // native dependency, so the FirebaseMessagingService / RemoteMessage
    // classes are not automatically on our app's compile classpath. The BOM
    // keeps versions aligned with whatever firebase-core resolves to via
    // google-services.json.
    //
    // Note: as of Firebase BOM 33.x the -ktx variants were deprecated and
    // their Kotlin extensions folded into the main artifact. Use the plain
    // `firebase-messaging` here, not `firebase-messaging-ktx`.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
