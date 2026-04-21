# PayU / Google Pay missing classes
-dontwarn com.google.android.apps.nbu.paisa.inapp.client.api.**

# Flutter Play Core (deferred components – optional dependency)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
