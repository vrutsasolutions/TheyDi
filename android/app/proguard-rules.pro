# ── Razorpay ──────────────────────────────────────────────────────────────
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**

# Optional but often needed alongside Razorpay
-keepattributes *Annotation*
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── camera plugin ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.camera.** { *; }
-dontwarn io.flutter.plugins.camera.**

# ── ML Kit face detection ────────────────────────────────────────────────
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**
-keep class com.google.android.gms.internal.mlkit_vision_face.** { *; }
-dontwarn com.google.android.gms.internal.mlkit_vision_face.**

# Keep native method signatures Flutter plugins rely on
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── image_cropper / uCrop ────────────────────────────────────────────────
# UCropActivity is only referenced from AndroidManifest.xml + reflection
# inside the plugin, so R8 doesn't see it as "used" and can strip the class
# or its resources when isMinifyEnabled/isShrinkResources are on. That
# reproduces the ActivityNotFoundException crash in release builds only.
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }
-dontwarn com.yalantis.ucrop**

# ── image_picker ─────────────────────────────────────────────────────────
-keep class io.flutter.plugins.imagepicker.** { *; }

# ── video_thumbnail ──────────────────────────────────────────────────────
-keep class xyz.justsoft.video_thumbnail.** { *; }

# ── flutter_pdfview ──────────────────────────────────────────────────────
-keep class com.example.flutter_pdfview.** { *; }
-keep class com.shockwave.** { *; }

# ── record (audio) ───────────────────────────────────────────────────────
-keep class com.llfbandit.record.** { *; }