plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Google services Gradle plugin (processes google-services.json for Firebase).
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.accrete.billberrylite"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (backports java.time APIs).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.accrete.billberrylite"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

//    buildTypes {
//        release {
//            // TODO: Add your own signing config for the release build.
//            // Signing with the debug keys for now, so `flutter run --release` works.
//            signingConfig = signingConfigs.getByName("debug")
//        }
//    }

    buildTypes {
        getByName("release") {
            // Use the debug signing config for now as we discussed
            signingConfig = signingConfigs.getByName("debug")

            // Correct Kotlin Script (KTS) syntax:
            isMinifyEnabled = true
            isShrinkResources = true

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Import the Firebase BoM — pins compatible versions for all Firebase libs.
    implementation(platform("com.google.firebase:firebase-bom:34.16.0"))

    // When using the BoM, don't specify versions in Firebase dependencies.
    implementation("com.google.firebase:firebase-analytics")

    // Add other desired Firebase products here (versions omitted — managed by the BoM):
    // https://firebase.google.com/docs/android/setup#available-libraries
}

flutter {
    source = "../.."
}
