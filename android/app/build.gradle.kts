plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("com.google.gms.google-services") // must be in app module
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.study_buddy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.study_buddy"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // (Leftover from Auth0 — harmless; remove if you want)
        manifestPlaceholders["auth0Scheme"] = "com.studybuddy"
        manifestPlaceholders["auth0Domain"] = "dev-qcz5hdonm0stlozz.us.auth0.com"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Align Firebase Android libs
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
}
