import com.android.build.gradle.LibraryExtension
import org.gradle.api.JavaVersion
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

group = "com.jieli.otasdk"
version = "1.0-SNAPSHOT"

val kotlinVersion = "2.2.20"

buildscript {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.12.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.2.20")
    }
}

rootProject.allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/central") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        maven { url = uri("https://jitpack.io") }
        flatDir {
            dirs(project(":jl_ota").file("libs"))
        }
    }
}

apply(plugin = "com.android.library")
apply(plugin = "kotlin-android")
apply(plugin = "kotlin-kapt")

extensions.configure<LibraryExtension>("android") {
    namespace = "com.jieli.otasdk"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    sourceSets {
        getByName("main") {
            java.srcDir("src/main/kotlin")
        }
        getByName("test") {
            java.srcDir("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 24
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    buildFeatures {
        buildConfig = true
    }

    testOptions {
        unitTests.all {
            it.useJUnitPlatform()
            it.outputs.upToDateWhen { false }

            it.testLogging {
                events("passed", "skipped", "failed", "standardOut", "standardError")
                showStandardStreams = true
            }
        }
    }
}

tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

dependencies {
    add("testImplementation", "org.jetbrains.kotlin:kotlin-test")
    add("testImplementation", "org.mockito:mockito-core:5.0.0")

    add("implementation", "org.jetbrains.kotlin:kotlin-stdlib:$kotlinVersion")
    add("implementation", mapOf("name" to "jl-component-lib_V1.4.0_10400-release", "ext" to "aar"))
    add("implementation", mapOf("name" to "jl_bt_ota_V1.11.0_11015-release", "ext" to "aar"))
    add("implementation", mapOf("name" to "jl_file_transfer_V1.0.0-release", "ext" to "aar"))

    add("implementation", "com.github.permissions-dispatcher:permissionsdispatcher:4.9.2")
    add("kapt", "com.github.permissions-dispatcher:permissionsdispatcher-processor:4.9.2")

    add("implementation", platform("com.squareup.okhttp3:okhttp-bom:4.12.0"))
    add("implementation", "com.squareup.okhttp3:logging-interceptor:4.10.0")
    add("implementation", "com.squareup.okhttp3:mockwebserver:4.10.0")

    add("implementation", "androidx.lifecycle:lifecycle-viewmodel-ktx:2.4.0")
    add("implementation", "androidx.activity:activity-ktx:1.2.3")
    add("implementation", "androidx.fragment:fragment:1.3.6")
    add("implementation", "com.koushikdutta.async:androidasync:3.1.0")
    add("implementation", "com.jakewharton.timber:timber:4.1.2")

    add("implementation", "com.hwangjr.rxbus:rxbus:1.0.5") {
        exclude(group = "com.jakewharton.timber", module = "timber")
    }

    add("implementation", "androidx.appcompat:appcompat:1.7.1")
    add("implementation", "androidx.annotation:annotation:1.3.0")
    add("implementation", "org.conscrypt:conscrypt-android:2.5.3")
}
