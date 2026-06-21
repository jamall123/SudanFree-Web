# Flutter ProGuard Rules for Sudan Free App
# تحسين حجم APK للسوق السوداني

# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }

# Firebase Messaging (Notifications)
-keep class com.google.firebase.messaging.** { *; }
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationCompat$* { *; }

# Hive Local Storage
-keep class hive.** { *; }
-keep class ** implements hive.TypeAdapter { *; }

# Cloudinary
-keep class com.cloudinary.** { *; }
-dontwarn com.cloudinary.**

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# CachedNetworkImage
-keep class com.github.bumptech.glide.** { *; }
-dontwarn com.github.bumptech.glide.**

# Google Play Core (Fix for SplitCompat error)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.** { *; }

# Keep model classes (for JSON serialization)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# General optimizations
-optimizationpasses 5
-dontusemixedcaseclassnames
-verbose

# Remove logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}
