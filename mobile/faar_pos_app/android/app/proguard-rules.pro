# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLite Native Libs
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**

# Mobile Scanner
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Bluetooth Low Energy
-keep class com.boskokg.flutter_blue_plus.** { *; }
-dontwarn com.boskokg.flutter_blue_plus.**

# Secure Storage
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**
