# WebSight ProGuard / R8 rules
# Keep Flutter, Firebase, and platform integrations across release shrinking.

# --- Flutter ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# --- Kotlin / Coroutines ---
-keep class kotlin.Metadata { *; }
-dontwarn kotlinx.coroutines.**

# --- AndroidX ---
-keep class androidx.appcompat.** { *; }
-keep class androidx.camera.** { *; }
-keep class androidx.lifecycle.** { *; }

# --- ML Kit Barcode Scanning ---
# Models are dynamic; reflection is used for descriptors.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_** { *; }
-dontwarn com.google.mlkit.**

# --- Google Mobile Ads + UMP ---
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-dontwarn com.google.android.gms.**

# --- Firebase + Crashlytics ---
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-keep class com.google.firebase.crashlytics.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keepattributes SourceFile,LineNumberTable
-keepattributes *Annotation*
-keep public class * extends java.lang.Exception

# --- Play Core (in-app updates, app-update-ktx, integrity) ---
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.integrity.** { *; }
-dontwarn com.google.android.play.**

# --- WebView JavaScript interface (the bridge name is configurable; protect generic) ---
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# --- Keep model classes parsed from JSON (json_serializable generated) ---
-keep class com.app.websight.** { *; }

# --- Stripe / future plugins safety net ---
-dontnote **
