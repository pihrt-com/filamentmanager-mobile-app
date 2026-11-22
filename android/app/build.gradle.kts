import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val defaultSigningPropertiesFile = File(
    System.getProperty("user.home"),
    "android-keys/filamentmanager-mobile-signing.properties",
)
val signingPropertiesFile = System.getenv("FILAMENTMANAGER_SIGNING_PROPERTIES")
    ?.takeIf { it.isNotBlank() }
    ?.let(::File)
    ?: defaultSigningPropertiesFile
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        load(FileInputStream(signingPropertiesFile))
    }
}
val configuredStoreFile = signingProperties.getProperty("storeFile")
val resolvedStoreFile = configuredStoreFile?.let { configuredPath ->
    val configuredFile = File(configuredPath)
    if (configuredFile.isFile) {
        configuredFile
    } else {
        File(signingPropertiesFile.parentFile, configuredFile.name)
    }
}
val releaseSigningAvailable =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all {
        !signingProperties.getProperty(it).isNullOrBlank()
    } && resolvedStoreFile?.isFile == true

android {
    namespace = "com.pihrt.filamentmanager.mobile"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pihrt.filamentmanager.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 31
        targetSdk = 37
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (releaseSigningAvailable) {
                storeFile = resolvedStoreFile
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningAvailable) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    implementation("androidx.credentials:credentials:1.7.0-alpha03")
    implementation("androidx.credentials:credentials-play-services-auth:1.7.0-alpha03")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.10.0")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
