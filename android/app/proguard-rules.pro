# حياتي: قواعد R8 عشان التصغير ميكسرش الإضافات

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications (بيستخدم Gson لحفظ الإشعارات المجدولة)
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken

# الويدجت بتاع الشاشة الرئيسية
-keep class com.hayati.** { *; }
-keep class es.antonborri.home_widget.** { *; }

# Firebase / Google Sign-In
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# التعرف على الصوت والبصمة
-keep class com.csdcorp.speech_to_text.** { *; }
-keep class androidx.biometric.** { *; }

# Play Core (مش مستخدم بس Flutter بيشير له)
-dontwarn com.google.android.play.core.**
