import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing credentials from android/key.properties.
// The file lives outside source control (.gitignore'd).
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

    // Java 17, not 11. Three plugins are compiled at 17 and will not link
    // against an 11 target: mobile_scanner, camera_android_camerax and
    // flutter_image_compress_common. AGP 8.13 requires JDK 17 to run anyway.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
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
            // No keystore, no release signing config. There is deliberately no
            // fall back to the debug key: an AAB signed with CN=Android Debug
            // looks exactly like a real one until Play rejects it, and the
            // build that produced it was 25 minutes long.
            if (hasRealKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

}

// Fail the release build when there is no keystore — do not warn.
//
// This used to call `logger.warn` and carry on with debug signing. The warning
// was never seen: `flutter build` runs Gradle with `-q`, which suppresses
// warn-level output, so a debug-signed release bundle was produced in complete
// silence. Verified by reading the certificate out of the resulting .aab —
// CN=Android Debug, with nothing in the log.
//
// Thrown from `doFirst` rather than at configuration time on purpose: the
// project must still configure and build DEBUG for anyone without the keystore
// (CI, a contributor). Only assembling or bundling a release stops.
if (!hasRealKeystore) {
    // Resolved at configuration time so the task action captures plain Files
    // and does not reach back into the project while it runs.
    val staleReleaseDirs =
        listOf("outputs/bundle/release", "outputs/apk/release")
            .map { layout.buildDirectory.dir(it).get().asFile }
    val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile

    tasks.matching { it.name.matches(Regex("(assemble|bundle).*Release")) }
        .configureEach {
            doFirst {
                // `doFirst` runs AFTER this task's dependencies, so packaging
                // has already written an unsigned artefact by now — and it
                // overwrites the signed one from a previous good build. Leaving
                // it there means the next person to look in outputs/ finds a
                // file that looks finished and is not signed. Take it out
                // before failing.
                val removed = mutableListOf<String>()
                staleReleaseDirs.filter { it.exists() }.forEach {
                    if (it.deleteRecursively()) removed += it.path
                }
                flutterApkDir.listFiles()
                    ?.filter { it.isFile && it.name.contains("release") }
                    ?.forEach { if (it.delete()) removed += it.path }
                // The list goes in the exception, not through the logger.
                // `-q` leaves only QUIET and ERROR alive, so `logger.lifecycle`
                // is swallowed exactly like the `logger.warn` this guard
                // replaced — measured, not assumed. An exception message always
                // reaches the terminal.
                val alsoRemoved =
                    if (removed.isEmpty()) ""
                    else "\n\nRemoved the unsigned output it had already " +
                        "written:\n  " + removed.joinToString("\n  ")
                throw GradleException(
                    "Release signing is not configured: android/key.properties " +
                        "is missing. Copy android/key.properties.example to " +
                        "android/key.properties and fill in the keystore " +
                        "details. Refusing to build an unsigned release " +
                        "rather than producing one Google Play will reject." +
                        alsoRemoved
                )
            }
        }
}

flutter {
    source = "../.."
}
