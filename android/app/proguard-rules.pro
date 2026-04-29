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

# Keep app's MethodChannel handler
-keep class com.example.enagarsewa.** { *; }

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
