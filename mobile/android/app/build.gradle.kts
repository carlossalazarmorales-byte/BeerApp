import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (Phase 15, Stage 2). Reads a git-ignored `android/key.properties` -- never
// committed, see `.gitignore` and `android/.gitignore` -- pointing at a private keystore kept
// outside git. Claude never generates, holds or requests the keystore, its passwords, or any
// signing secret; the owner creates and manages the upload key locally. See docs/RELEASE.md,
// section 8 "Signing", for the exact owner-operated setup.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

// Explicit, non-default opt-in for a LOCAL INSPECTION ONLY debug-signed "release" build (merged
// manifest / build-shape inspection before real signing exists -- see docs/RELEASE.md, Stage 1A).
// NEVER pass this for a build meant for Google Play: it does not provide real release signing,
// and the default (this flag absent) is to fail the release build rather than fall back to it.
val allowDebugSigningForReleaseInspection =
    (project.findProperty("allowDebugSigningForReleaseInspection") as String?).toBoolean()

val releaseSigningRequiredMessage =
    """
    |Release signing is not configured for BeerApp.
    |
    |android/key.properties is missing, and -PallowDebugSigningForReleaseInspection=true was not
    |passed either, so this release build has been stopped rather than silently signed with the
    |debug key.
    |
    |For a real Google Play release build: the owner creates the upload keystore and
    |android/key.properties locally first -- see docs/RELEASE.md, section 8 "Signing". There is
    |no fallback to the debug signing key for a store release build.
    |
    |For a LOCAL INSPECTION ONLY release build (e.g. merged-manifest inspection) --
    |NEVER UPLOAD THIS BUILD TO GOOGLE PLAY -- pass:
    |    -PallowDebugSigningForReleaseInspection=true
    """.trimMargin()

android {
    namespace = "com.carlossalazarmorales.beerapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Final release identity (Phase 15, Stage 2 decision) -- do not rename without also
        // renaming the iOS bundle id and the auth/deep-link scheme in the same change.
        applicationId = "com.carlossalazarmorales.beerapp"
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseSigning -> signingConfigs.getByName("release")
                allowDebugSigningForReleaseInspection -> signingConfigs.getByName("debug")
                // Neither the real keystore nor the explicit inspection opt-in is present: leave
                // this unsigned. The check below fails assembleRelease/bundleRelease clearly and
                // early, rather than letting Gradle emit an unsigned or ambiguous artifact.
                else -> null
            }
        }
    }
}

// Fail-closed check: a "release" build with no real signing and no explicit inspection opt-in
// must not silently produce a debug-signed (or unsigned) artifact. `taskGraph.whenReady` runs
// once the requested tasks are fully resolved but BEFORE any of them execute, so this fails
// immediately -- not after compiling the release variant -- whenever `assembleRelease` or
// `bundleRelease` (Flutter's own task names for `flutter build apk|appbundle --release`,
// confirmed against this project's Gradle output; no product flavors exist here) is anywhere in
// the task graph, whether requested directly or pulled in as a dependency.
if (!hasReleaseSigning && !allowDebugSigningForReleaseInspection) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name == "assembleRelease" || it.name == "bundleRelease" }) {
            throw GradleException(releaseSigningRequiredMessage)
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
