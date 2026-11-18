import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing uses a local *upload* key (Play App Signing holds the app key).
// The properties file is deliberately outside the project tree; its path is
// supplied through the environment so no secret is committed or logged.
val uploadKeyPropertiesFile = System.getenv("DOMINO_UPLOAD_KEY_PROPERTIES")
    ?.let { rootProject.file(it) }
    ?: rootProject.file("upload-key.properties")

val uploadKeyProperties = Properties().apply {
    if (uploadKeyPropertiesFile.exists()) {
        uploadKeyPropertiesFile.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.dominoshak.domino_shak"
    // Google Play target requirement: API 36+.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Final application ID confirmed by the project owner (RELEASE_DECISIONS.md).
        applicationId = "com.dominoshak.domino_shak"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            val store = uploadKeyProperties.getProperty("storeFile")
            if (store != null) {
                storeFile = rootProject.file(store)
                storePassword = uploadKeyProperties.getProperty("storePassword")
                keyAlias = uploadKeyProperties.getProperty("keyAlias")
                keyPassword = uploadKeyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (uploadKeyProperties.getProperty("storeFile") == null) {
                throw GradleException(
                    "Release signing requires DOMINO_UPLOAD_KEY_PROPERTIES pointing to " +
                        "a properties file outside the project. Debug signing is not allowed."
                )
            }
            signingConfig = signingConfigs.getByName("upload")
        }
    }
}

flutter {
    source = "../.."
}
