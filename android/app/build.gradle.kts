import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads android/app/google-services.json to configure Firebase Cloud
    // Messaging - carried over from the captain app when the apps merged.
    id("com.google.gms.google-services")
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

// Play Store release signing - loaded from android/key.properties (gitignored,
// never committed) if present. CI writes this file from repository secrets
// right before the build (see build-customer-apk.yml); a developer building
// locally without it falls through to the debug key below, same as before -
// only `flutter build appbundle` for an actual Play Store upload needs the
// real key.
val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keyPropertiesFile.exists()
if (hasReleaseSigning) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.alhudhud.captain"
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
        // since the two APKs are signed with different debug keys. Renamed
        // again from com.alhudhud.customer for the same reason: a fresh
        // GitHub Actions runner has no ~/.android/debug.keystore, so every
        // CI build was self-signing with a brand new, different key, and
        // installing over a previous download hit the same conflict.
        applicationId = "com.alhudhud.captain"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    signingConfigs {
        getByName("debug") {
            // Pinned to a keystore checked into the repo (debug-only key,
            // not used for Play Store signing) so every CI run - and every
            // local machine - signs with the same key. Without this, each
            // fresh GitHub Actions runner generates its own throwaway
            // debug.keystore and every release conflicts with the last.
            storeFile = file("$rootDir/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Real Play Store signing when key.properties is present (CI's
            // appbundle build); falls back to the debug key otherwise so
            // `flutter build apk --release`/`flutter run --release` keep
            // working unsigned-for-Play-Store, exactly as before.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    // NotificationCompat, used by TripForegroundService's required
    // persistent notification - flutter_local_notifications also pulls
    // this in transitively, but declared explicitly here so it doesn't
    // depend on that plugin's dependency tree staying exactly as it is.
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
