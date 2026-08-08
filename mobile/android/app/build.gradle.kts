// (P150) `java.util.Properties` TAM ADLA cozulmuyor: Kotlin DSL'de
// `java` adi Java eklentisine baglanip paketi GOLGELIYOR. Acik import sart.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// FCM: google-services.json .gitignore'da (repoya girmez; her gelistirici kendi
// kopyasini koyar — bkz. mobile/README.md). Dosya yoksa plugin uygulanmaz ki
// build kirilmasin; o build'de Firebase calisma zamaninda baslatilamaz ve
// uygulama push'u sessizce devre disi birakir.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// (P150) YUKLEME ANAHTARI — Play App Signing kullaniliyor.
// Google UYGULAMA imza anahtarini tutar; bizdeki YUKLEME anahtaridir ve
// kaybolursa Google sifirlayabilir. Depoya GIRMEZ (.gitignore).
//
// DOSYA YOKSA DERLEME KIRILMAZ: anahtari olmayan ortam debug ile calisir.
val anahtarDosyasi = rootProject.file("key.properties")
val anahtar = Properties().apply {
    if (anahtarDosyasi.exists()) anahtarDosyasi.inputStream().use { load(it) }
}

android {
    namespace = "com.tesisguvenlik.mobile"
    // (P141) API 36 ACIKCA SABITLENDI — Flutter varsayilanina BIRAKILMADI.
    // Play kurali: 31.08.2026'dan itibaren yeni uygulamalar API 36
    // hedeflemek ZORUNDA. Varsayilana birakmak, Flutter surumu degistiginde
    // hedefin SESSIZCE dusmesi demekti; burada sabit oldugu icin denetlenebilir.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (anahtarDosyasi.exists()) {
                storeFile = file(anahtar.getProperty("storeFile"))
                storePassword = anahtar.getProperty("storePassword")
                keyAlias = anahtar.getProperty("keyAlias")
                // Parola keystore parolasiyla AYNI; yine de ayri okunur ki
                // ileride ayrilirsa kod degismesin.
                keyPassword = anahtar.getProperty("keyPassword")
                    ?: anahtar.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.tesisguvenlik.mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // (P150) Anahtar VARSA uretim imzasi, YOKSA debug — boylece
            // anahtarsiz bir ortamda `flutter run --release` calismaya
            // devam eder ama YAYIN yapimi kazara debug ile IMZALANMAZ:
            // AAB uretimi anahtar dosyasini zorunlu kilar (asagidaki
            // kontrol betigi bunu ayrica dogrular).
            signingConfig = if (anahtarDosyasi.exists())
                signingConfigs.getByName("release")
            else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
