# PayU / Google Pay missing classes
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**

# Flutter Play Core (deferred components – optional dependency)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }

# Keep Flutter embedding
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.app.** { *; }

# PayU SDK — full keep required: PayU internally registers Firebase components.
# Selective keep was breaking Firebase CycleDetector (NPE on Set.isEmpty() at launch).
-keep class com.payu.** { *; }
-dontwarn com.payu.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Firebase — keep classes AND interfaces (interfaces get stripped separately by R8)
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase ComponentRegistrar — CRITICAL: ServiceLoader discovers registrars by class name.
# ANY package can implement ComponentRegistrar (not just com.google.firebase).
# If stripped → CycleDetector.toGraph() gets null dependency Set → NPE crash on launch.
-keep class * implements com.google.firebase.components.ComponentRegistrar { *; }
-keepclassmembers class * implements com.google.firebase.components.ComponentRegistrar {
    public java.util.List getComponents();
}

# Google datatransport — Firebase Messaging/Analytics depend on this transport layer.
# Lives in com.google.android.datatransport, NOT com.google.firebase — easy to miss.
-keep class com.google.android.datatransport.** { *; }
-keep interface com.google.android.datatransport.** { *; }
-dontwarn com.google.android.datatransport.**

# OkHttp3 — Firebase uses OkHttp internally for SSL/TLS platform detection.
# Previous crash: okhttp3.internal.platform obfuscated → "d","e" in stack trace → NPE.
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**

# Preserve generic type signatures and annotations (needed by Firebase + OkHttp reflection)
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# SQLite native layer — must be kept (JNI boundary)
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# SQFlite Flutter plugin — keep only the MethodChannel handler (W3 mitigation).
# Internal query-execution class (e.java) and IP-disclosure class (i.java) are NOT kept
# so R8 will obfuscate + shrink them. Our Dart code exclusively uses parameterized
# db.query()/db.insert()/db.delete() — never rawQuery with user input.
-keep class com.tekartik.sqflite.SqflitePlugin { *; }
-keep class com.tekartik.sqflite.DatabaseWorker { *; }
-dontwarn com.tekartik.sqflite.**

# Strip sqflite internal server-discovery class (W6: IP Address Disclosure).
# This class holds hardcoded internal IPs used only for sqflite's dev tooling — not runtime.
-assumenosideeffects class com.tekartik.sqflite.i { *; }

# Keep only MainActivity class name — Android needs it to instantiate by name.
# R8 obfuscates all internal methods (isDeviceRooted, checkEmulator, getPlayIntegrityToken, etc.)
-keep class com.vdsai.enagaesewa.MainActivity
-keepclassmembers class com.vdsai.enagaesewa.MainActivity {
    public void configureFlutterEngine(io.flutter.embedding.engine.FlutterEngine);
}

# Remove ALL Android logging in release builds
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
    public static int wtf(...);
    public static boolean isLoggable(...);
}
