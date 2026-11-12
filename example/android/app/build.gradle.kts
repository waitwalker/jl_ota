plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.jieli.otasdk.example"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/kotlin")
        }
    }

    defaultConfig {
        applicationId = "com.jieli.otasdk"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

dependencies {
    compileOnly(mapOf("name" to "jl_bt_ota_V1.11.0_11015-release", "ext" to "aar"))
    implementation(mapOf("name" to "jl_file_transfer_V1.0.0-release", "ext" to "aar"))
    implementation("com.koushikdutta.async:androidasync:3.1.0")
    implementation("com.jakewharton.timber:timber:4.1.2")
    implementation("com.hwangjr.rxbus:rxbus:1.0.5") {
        exclude(group = "com.jakewharton.timber", module = "timber")
    }
    implementation(platform("com.squareup.okhttp3:okhttp-bom:4.12.0"))
    implementation("com.squareup.okhttp3:okhttp")
}
