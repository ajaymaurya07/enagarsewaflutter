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

# PayU SDK
-keep class com.payu.** { *; }
-dontwarn com.payu.**

# Google Play Services
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# SQLite / SQFlite
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

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
