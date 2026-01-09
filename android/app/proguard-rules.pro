# --- Flutter Wrapper Standard Rules ---
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- Google ML Kit Rules (Fix Error Sebelumnya) ---
-dontwarn com.google.mlkit.**
-keep class com.google.mlkit.** { *; }

# --- Google Play Core / Split Compat (Fix Error SEKARANG) ---
# Flutter punya fitur deferred components, tapi R8 komplain kalau library-nya tidak ada.
# Kita ignore saja karena kemungkinan besar aplikasi Anda tidak pakai fitur split install ini.
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**