# BansheeRun ProGuard rules

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep BansheeLib
-keep class com.bansheerun.BansheeLib { *; }
