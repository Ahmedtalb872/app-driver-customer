import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional Google Maps SDK API key for the Phase 2 destination map picker.
// Configured via android/local.properties (gitignored) so it never lands in
// source control; empty by default, which just means map tiles won't load
// until a real key is supplied - see that file for details.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localProperties.load(FileInputStream(localPropertiesFile))
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

android {
    namespace = "com.alhudhud.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // Distinct from the captain app's applicationId (both apps are
        // forks of the same original codebase and, before this, shared
        // "com.alhudhud.alhudhud" - installing both on one test device hit
        // Android's "package conflicts with an existing package" refusal
        // since the two APKs are signed with different debug keys.
        applicationId = "com.alhudhud.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

configurations.all {
    // cronet_http (via play-services-cronet) pulls in both
    // org.chromium.net:cronet-api and org.chromium.net:cronet-shared, two
    // separate artifacts that both declare the same "org.chromium.net"
    // namespace in their embedded manifests - AGP 9's manifest merger
    // rejects that as a duplicate-namespace error. The actual Cronet
    // implementation is loaded at runtime through Google Play Services;
    // cronet-shared's classes are only needed by the (unused, since
    // cronetHttpNoPlay stays false) embedded/standalone Cronet variant, so
    // dropping it here just removes the redundant, colliding manifest.
    exclude(group = "org.chromium.net", module = "cronet-shared")
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
