plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key: read from root local.properties (google.maps.api_key=...) or env GOOGLE_MAPS_API_KEY
val localProperties = java.util.Properties()
val localFile = rootProject.file("local.properties")
if (localFile.exists()) localProperties.load(localFile.inputStream())
val googleMapsApiKey = localProperties.getProperty("google.maps.api_key") ?: System.getenv("GOOGLE_MAPS_API_KEY") ?: ""

android {
    namespace = "com.nida.islamiuygulama"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.nida.islamiuygulama"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 32
        // versionName = single source for app display. After edit: Run Task "Run app (with version)" or scripts\run_app.bat
        versionName = "2026.03.11"
    }

    signingConfigs {
        create("release") {
            storeFile = file("my-upload-key.keystore")
            storePassword = "752148963"
            keyAlias = "ihmuin"
            keyPassword = "752148963"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
