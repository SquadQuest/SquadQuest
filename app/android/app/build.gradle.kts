plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.squadquest"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Base application id. The `prod` flavor keeps it as-is (v2 ships as the
        // v1 store update — bundle id is deliberately preserved; see
        // specs/behaviors/v1-migration.md). The `dev` flavor suffixes it so a
        // milestone build installs alongside v1/prod on the same device.
        applicationId = "app.squadquest"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Build channels. `prod` is the real store identity; `dev` is the sideload-
    // alongside identity for on-device milestone testing. Android-only for now
    // (iOS flavor schemes are a later follow-up).
    flavorDimensions += "channel"
    productFlavors {
        create("prod") {
            dimension = "channel"
            manifestPlaceholders["appLabel"] = "SquadQuest"
        }
        create("dev") {
            dimension = "channel"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "SquadQuest Dev"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
