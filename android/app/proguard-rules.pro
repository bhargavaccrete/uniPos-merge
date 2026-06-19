# flutter_local_notifications — keep plugin + its Gson models so release
# minification doesn't strip them (notifications silently fail otherwise).
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# Gson (used by the plugin to (de)serialize scheduled notifications)
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepattributes Signature
-keepattributes *Annotation*
