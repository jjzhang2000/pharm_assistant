# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# flutter_local_notifications
-keep class com.dexterous.** { *; }

# Keep custom application class
-keep class com.medicine.pharm_assistant.** { *; }

# Prevent R8 from stripping drawable resources used by notification plugin
-keep class androidx.core.app.NotificationCompat { *; }
-keep class androidx.core.app.NotificationManagerCompat { *; }