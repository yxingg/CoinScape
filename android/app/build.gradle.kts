plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.coinscape"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // ---------- 新增：固定签名配置 ----------
    signingConfigs {
        // 创建一个名为 "fixed" 的签名配置，debug 和 release 都用它
        fixed {
            storeFile file('my-release-key.jks')   // keystore 文件放在 android/app/ 下
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }
    }

    defaultConfig {
        applicationId = "com.example.coinscape"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        // 显式声明 debug 构建类型，并强制使用我们的固定签名
        debug {
            signingConfig signingConfigs.fixed
        }
        release {
            signingConfig signingConfigs.fixed   // 原本用的是 debug 签名，现在改成 fixed
        }
    }
}

flutter {
    source = "../.."
}