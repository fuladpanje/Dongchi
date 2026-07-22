plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.takbaran.dangchi"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17" // هشدار فقط، خطا نمی‌ده
    }

    defaultConfig {
        applicationId = "com.takbaran.dangchi"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // بهینه‌سازی برای Play Protect
        vectorDrawables.useSupportLibrary = true
    }

    signingConfigs {
        create("release") {
            storeFile = file("key.jks")
            storePassword = "8652211"
            keyAlias = "my_key_alias"
            keyPassword = "8652211"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            
            // بهینه‌سازی‌های امنیتی
            isDebuggable = false
            isJniDebuggable = false
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
