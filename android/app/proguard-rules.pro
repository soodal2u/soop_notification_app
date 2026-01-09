# Flutter Background Service
-keep class id.flutter.flutter_background_service.** { *; }
-keep class com.dexterous.** { *; }

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Keep entry points
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# HTTP / JSON
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class com.google.gson.** { *; }

# Preserve line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable
