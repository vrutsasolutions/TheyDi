# Razorpay
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Optional but often needed alongside Razorpay
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }