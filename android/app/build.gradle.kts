import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing credentials from android/key.properties.
// The file lives outside source control (.gitignore'd). When it's missing
// (e.g. CI building debug only, or contributors without the keystore),
// release builds fall back to debug signing — but that fallback is
// flagged with a warning at configuration time so it's obvious.
val keystoreProperties = Properties().apply {
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile))
    }
}
val hasRealKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "kg.salamat.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "kg.salamat.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasRealKeystore) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasRealKeystore) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Loud warning so this doesn't silently slip into a Play
                // upload. The actual Play upload itself will be rejected
                // by Google because debug certs are not allowed.
                logger.warn(
                    "⚠  Release build will use DEBUG signing — " +
                        "android/key.properties is missing. " +
                        "Do NOT upload this build to Google Play."
                )
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
