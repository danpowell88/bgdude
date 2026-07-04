# Keep pumpx2 message classes — they're reflected over by opcode and must not be
# renamed/stripped by R8.
-keep class com.jwoglom.pumpx2.** { *; }
-keep class com.welie.blessed.** { *; }
-dontwarn com.jwoglom.pumpx2.**
-dontwarn com.welie.blessed.**

# Health Connect / androidx.health
-keep class androidx.health.** { *; }
-dontwarn androidx.health.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
