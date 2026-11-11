import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Secretos locales (no versionados) ───────────────────────────────
// local.properties: MAPS_API_KEY del SDK de Google Maps en Android.
// key.properties: firma del APK release. Nunca se versionan.
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}

// Solo los builds release exigen secretos; debug debe seguir funcionando
// aunque no exista key.properties.
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

val keystoreKeys = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

if (isReleaseBuild) {
    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Falta android/key.properties, ver README (sección \"Compilar el APK (Windows)\"). " +
                "El APK release necesita un keystore propio; no se firmará con la clave debug."
        )
    }

    val missingKeystoreKeys = keystoreKeys.filter {
        keystoreProperties.getProperty(it).isNullOrBlank()
    }
    if (missingKeystoreKeys.isNotEmpty()) {
        throw GradleException(
            "android/key.properties está incompleto: falta " +
                "${missingKeystoreKeys.joinToString(", ")}. Ver README."
        )
    }
}

val hasReleaseSigning = keystorePropertiesFile.exists() &&
    keystoreKeys.all { !keystoreProperties.getProperty(it).isNullOrBlank() }

val mapsApiKey: String = (
    localProperties.getProperty("MAPS_API_KEY")
        ?: System.getenv("MAPS_API_KEY")
        ?: ""
    ).trim()

if (mapsApiKey.isEmpty()) {
    if (isReleaseBuild) {
        throw GradleException(
            "Falta MAPS_API_KEY. Defínela en android/local.properties o en la " +
                "variable de entorno MAPS_API_KEY. Ver README."
        )
    } else {
        logger.warn(
            "ADVERTENCIA: MAPS_API_KEY no está definida; el mapa de Android " +
                "quedará sin API key en este build debug."
        )
    }
}

android {
    // No cambiar sin mover también el paquete de MainActivity.
    namespace = "com.example.mister_chef"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ID único de la app en Play Store. Después de publicar ya no se puede cambiar.
        applicationId = "com.logigo.misterchef"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // El manifest usa ${MAPS_API_KEY}; se inyecta desde local.properties
        // o desde la variable de entorno del mismo nombre.
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Sin key.properties no se firma con debug: el build release ya
            // falló arriba con un mensaje claro.
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}