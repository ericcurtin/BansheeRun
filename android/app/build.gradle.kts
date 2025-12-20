plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

val generateAppIcons by tasks.registering {
    val resDir = file("src/main/res")
    val logoUrl = "https://github.com/user-attachments/assets/b1e0a8f6-24fa-4bc6-9a6b-5e1a9acc01be"

    outputs.dir(resDir.resolve("mipmap-mdpi"))
    outputs.dir(resDir.resolve("mipmap-hdpi"))
    outputs.dir(resDir.resolve("mipmap-xhdpi"))
    outputs.dir(resDir.resolve("mipmap-xxhdpi"))
    outputs.dir(resDir.resolve("mipmap-xxxhdpi"))
    outputs.dir(resDir.resolve("drawable-mdpi"))
    outputs.dir(resDir.resolve("drawable-hdpi"))
    outputs.dir(resDir.resolve("drawable-xhdpi"))
    outputs.dir(resDir.resolve("drawable-xxhdpi"))
    outputs.dir(resDir.resolve("drawable-xxxhdpi"))

    doLast {
        val tmpDir = File(System.getProperty("java.io.tmpdir"), "banshee-icons")
        tmpDir.mkdirs()

        val logoFile = File(tmpDir, "logo.png")
        val squareFile = File(tmpDir, "logo_square.png")

        // Download logo
        exec {
            commandLine("curl", "-L", "-o", logoFile.absolutePath, logoUrl)
        }

        // Check if sips (macOS) or convert (ImageMagick) is available
        val hasSips = try {
            exec { commandLine("which", "sips"); isIgnoreExitValue = true }.exitValue == 0
        } catch (e: Exception) { false }

        val hasConvert = try {
            exec { commandLine("which", "convert"); isIgnoreExitValue = true }.exitValue == 0
        } catch (e: Exception) { false }

        if (hasSips) {
            // macOS: use sips
            exec { commandLine("sips", "-p", "700", "700", logoFile.absolutePath, "--out", squareFile.absolutePath) }

            // Mipmap icons (launcher icons for older devices)
            val mipmapSizes = mapOf("mdpi" to 48, "hdpi" to 72, "xhdpi" to 96, "xxhdpi" to 144, "xxxhdpi" to 192)
            mipmapSizes.forEach { (density, size) ->
                val dir = resDir.resolve("mipmap-$density").apply { mkdirs() }
                exec { commandLine("sips", "-z", size.toString(), size.toString(), squareFile.absolutePath, "--out", dir.resolve("ic_launcher.png").absolutePath) }
                exec { commandLine("cp", dir.resolve("ic_launcher.png").absolutePath, dir.resolve("ic_launcher_round.png").absolutePath) }
            }

            // Drawable foreground icons (for adaptive icons)
            val drawableSizes = mapOf("mdpi" to 108, "hdpi" to 162, "xhdpi" to 216, "xxhdpi" to 324, "xxxhdpi" to 432)
            drawableSizes.forEach { (density, size) ->
                val dir = resDir.resolve("drawable-$density").apply { mkdirs() }
                exec { commandLine("sips", "-z", size.toString(), size.toString(), squareFile.absolutePath, "--out", dir.resolve("ic_launcher_foreground.png").absolutePath) }
            }
        } else if (hasConvert) {
            // Linux/CI: use ImageMagick
            exec { commandLine("convert", logoFile.absolutePath, "-gravity", "center", "-background", "none", "-extent", "700x700", squareFile.absolutePath) }

            val mipmapSizes = mapOf("mdpi" to 48, "hdpi" to 72, "xhdpi" to 96, "xxhdpi" to 144, "xxxhdpi" to 192)
            mipmapSizes.forEach { (density, size) ->
                val dir = resDir.resolve("mipmap-$density").apply { mkdirs() }
                exec { commandLine("convert", squareFile.absolutePath, "-resize", "${size}x${size}", dir.resolve("ic_launcher.png").absolutePath) }
                exec { commandLine("cp", dir.resolve("ic_launcher.png").absolutePath, dir.resolve("ic_launcher_round.png").absolutePath) }
            }

            val drawableSizes = mapOf("mdpi" to 108, "hdpi" to 162, "xhdpi" to 216, "xxhdpi" to 324, "xxxhdpi" to 432)
            drawableSizes.forEach { (density, size) ->
                val dir = resDir.resolve("drawable-$density").apply { mkdirs() }
                exec { commandLine("convert", squareFile.absolutePath, "-resize", "${size}x${size}", dir.resolve("ic_launcher_foreground.png").absolutePath) }
            }
        } else {
            throw GradleException("Neither sips (macOS) nor convert (ImageMagick) found. Please install ImageMagick.")
        }
    }
}

tasks.named("preBuild") {
    dependsOn(generateAppIcons)
}

android {
    namespace = "com.bansheerun"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.bansheerun"
        minSdk = 24
        targetSdk = 34
        versionCode = 1
        versionName = "0.1.0"

        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        create("release") {
            storeFile = file("release.keystore")
            storePassword = "bansheerun"
            keyAlias = "bansheerun"
            keyPassword = "bansheerun"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.activity:activity-ktx:1.8.2")
    implementation("com.google.android.gms:play-services-location:21.0.1")
    implementation("org.osmdroid:osmdroid-android:6.1.18")
}
