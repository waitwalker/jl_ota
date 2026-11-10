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

// 本地 AAR 会作为 runtime 依赖漏到 :app，必须让所有模块都能解析；Maven 仓仍只给杰理自己用。
val jlOtaLibsDir = file("libs")
rootProject.allprojects {
    repositories {
        flatDir {
            dirs(jlOtaLibsDir)
        }
    }
}

repositories {
    google()
    mavenCentral()
    maven { url = uri("https://maven.aliyun.com/repository/google") }
    maven { url = uri("https://maven.aliyun.com/repository/central") }
    maven { url = uri("https://maven.aliyun.com/repository/public") }
    maven { url = uri("https://jitpack.io") }
    flatDir {
        dirs(jlOtaLibsDir)
    }
}

apply(plugin = "com.android.library")
apply(plugin = "kotlin-android")

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
    add("testImplementation", "org.jetbrains.kotlin:kotlin-test-junit5:$kotlinVersion")
    add("testImplementation", "org.mockito:mockito-core:5.0.0")
    add("testRuntimeOnly", "org.junit.jupiter:junit-jupiter-engine:5.10.1")
    add("testRuntimeOnly", "org.junit.platform:junit-platform-launcher:1.10.1")

    add("implementation", "org.jetbrains.kotlin:kotlin-stdlib:$kotlinVersion")
    add("implementation", mapOf("name" to "jl-component-lib_V1.4.0_10400-release", "ext" to "aar"))
    add("implementation", mapOf("name" to "jl_bt_ota_V1.11.0_11015-release", "ext" to "aar"))

    add("implementation", "androidx.lifecycle:lifecycle-viewmodel-ktx:2.4.0")
    add("implementation", "androidx.fragment:fragment:1.3.6")
    add("implementation", "androidx.annotation:annotation:1.3.0")
}
