#!/usr/bin/env bash
set -euo pipefail

echo "Creating Amora Dating App (Com.DR.AmoraDating) Native Android Project..."

# 1. Create required Android directory structure
mkdir -p app/src/main/java/Com/DR/AmoraDating
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable

# --- Firebase config: app/google-services.json -------------------------------------------------
# The Google Services plugin turns this file into the Firebase resources (google_app_id, API key, ...)
# that FirebaseInitProvider reads at startup. If the file is missing, stale or for another package,
# the app fails at runtime with "Default FirebaseApp is not initialized".
GS_APP_ID="1:68441089345:android:eab3b068a5a6fc1548adc0"
GS_PACKAGE="Com.DR.AmoraDating"

# True when the given file belongs to this app (same Firebase app id AND same package name)
gs_is_current() {
    [ -f "$1" ] \
        && grep -q "\"mobilesdk_app_id\": *\"$GS_APP_ID\"" "$1" \
        && grep -q "\"package_name\": *\"$GS_PACKAGE\"" "$1"
}

GS_TMP="$(mktemp)"
cat << 'AMORA_EOF' > "$GS_TMP"
{
  "project_info": {
    "project_number": "68441089345",
    "project_id": "amora-dating-app-eeab3",
    "storage_bucket": "amora-dating-app-eeab3.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:68441089345:android:eab3b068a5a6fc1548adc0",
        "android_client_info": {
          "package_name": "Com.DR.AmoraDating"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyA3FfN3qPtF2TyuTFmDrv6TxKd_u5v3B9Q"
        }
      ],
      "services": {
        "appinvite_service": {
          "other_platform_oauth_client": []
        }
      }
    }
  ],
  "configuration_version": "1"
}
AMORA_EOF

if gs_is_current "app/google-services.json"; then
    echo "app/google-services.json is valid for $GS_PACKAGE, leaving it unchanged"
elif gs_is_current "google-services.json"; then
    cp google-services.json app/google-services.json
    echo "Copied the matching google-services.json from the repository root into app/"
else
    if [ -f "app/google-services.json" ]; then
        cp app/google-services.json app/google-services.json.bak
        echo "Existing app/google-services.json did not match this app; saved as app/google-services.json.bak"
    fi
    if [ -f "google-services.json" ]; then
        echo "Ignoring google-services.json in the repository root: it does not match $GS_PACKAGE"
    fi
    cp "$GS_TMP" app/google-services.json
    echo "Created app/google-services.json from the embedded Firebase config"
fi
rm -f "$GS_TMP"

# Fail early (before Gradle runs) if the file is still not usable
if ! gs_is_current "app/google-services.json"; then
    echo "ERROR: app/google-services.json is not valid for package $GS_PACKAGE" >&2
    exit 1
fi

# 2. Create gradle.properties
cat << 'AMORA_EOF' > gradle.properties
org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8
android.useAndroidX=true
kotlin.code.style=official
android.nonTransitiveRClass=true
AMORA_EOF

# 3. Create settings.gradle.kts
cat << 'AMORA_EOF' > settings.gradle.kts
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "AmoraDatingApp"
include(":app")
AMORA_EOF

# 4. Create root build.gradle.kts
cat << 'AMORA_EOF' > build.gradle.kts
plugins {
    id("com.android.application") version "8.7.2" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.0.21" apply false
    id("com.google.gms.google-services") version "4.4.2" apply false
}
AMORA_EOF

# 5. Create app/build.gradle.kts
cat << 'AMORA_EOF' > app/build.gradle.kts
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
    // Turns app/google-services.json into the Firebase resources the app reads at startup.
    // The build fails if the file is missing or does not match the applicationId, so an APK
    // without Firebase configuration can never be produced.
    id("com.google.gms.google-services")
}

// Optional release signing, driven by environment variables
val keystorePath: String? = System.getenv("KEYSTORE_PATH")
val hasKeystore: Boolean = (keystorePath ?: "").let { it.isNotBlank() && file(it).exists() }

android {
    namespace = "Com.DR.AmoraDating"
    compileSdk = 35

    defaultConfig {
        applicationId = "Com.DR.AmoraDating"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"

        vectorDrawables {
            useSupportLibrary = true
        }
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                storeFile = file(requireNotNull(keystorePath))
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: ""
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Without a keystore, fall back to the debug key so the release APK is still installable
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            isMinifyEnabled = false
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

dependencies {
    // AndroidX
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")
    implementation("androidx.activity:activity-compose:1.9.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    // Jetpack Compose (versions managed by the BOM)
    implementation(platform("androidx.compose:compose-bom:2024.10.01"))
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-graphics")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    debugImplementation("androidx.compose.ui:ui-tooling")

    // Image loading
    implementation("io.coil-kt:coil-compose:2.7.0")

    // Firebase (versions managed by the BOM)
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    implementation("com.google.firebase:firebase-messaging")
}
AMORA_EOF

# 6. Create app/proguard-rules.pro
cat << 'AMORA_EOF' > app/proguard-rules.pro
-keep class Com.DR.AmoraDating.** { *; }
-dontwarn com.google.firebase.**
AMORA_EOF

# 7. Create launcher icon drawable
cat << 'AMORA_EOF' > app/src/main/res/drawable/ic_amora_logo.xml
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path
        android:fillColor="#E11D48"
        android:pathData="M0,0h108v108h-108z" />
    <path
        android:fillColor="#FFFFFF"
        android:pathData="M54,79L50.38,75.7C37.5,64.02 29,56.32 29,46.88C29,39.18 35.05,33.12 42.75,33.12C47.1,33.12 51.28,35.15 54,38.35C56.72,35.15 60.9,33.12 65.25,33.12C72.95,33.12 79,39.18 79,46.88C79,56.32 70.5,64.02 57.62,75.72L54,79Z" />
</vector>
AMORA_EOF

# 8. Create AndroidManifest.xml
cat << 'AMORA_EOF' > app/src/main/AndroidManifest.xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

    <application
        android:allowBackup="false"
        android:icon="@drawable/ic_amora_logo"
        android:roundIcon="@drawable/ic_amora_logo"
        android:label="@string/app_name"
        android:supportsRtl="true"
        android:theme="@style/Theme.AmoraNative"
        android:usesCleartextTraffic="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:windowSoftInputMode="adjustResize">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>
</manifest>
AMORA_EOF

# 9. Create strings.xml and themes.xml
cat << 'AMORA_EOF' > app/src/main/res/values/strings.xml
<resources>
    <string name="app_name">Amora 18+</string>
</resources>
AMORA_EOF

cat << 'AMORA_EOF' > app/src/main/res/values/themes.xml
<resources>
    <style name="Theme.AmoraNative" parent="android:Theme.Material.Light.NoActionBar" />
</resources>
AMORA_EOF

# 10. Create Theme.kt
cat << 'AMORA_EOF' > app/src/main/java/Com/DR/AmoraDating/Theme.kt
package Com.DR.AmoraDating

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

private val AmoraLightColors = lightColorScheme(
    primary = Color(0xFFE11D48),
    secondary = Color(0xFF7B1FA2),
    tertiary = Color(0xFFD97706)
)

private val AmoraDarkColors = darkColorScheme(
    primary = Color(0xFFFB7185),
    secondary = Color(0xFFCE93D8),
    tertiary = Color(0xFFFBBF24)
)

@Composable
fun AmoraTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = if (darkTheme) AmoraDarkColors else AmoraLightColors,
        content = content
    )
}
AMORA_EOF

# 11. Create Models.kt
cat << 'AMORA_EOF' > app/src/main/java/Com/DR/AmoraDating/Models.kt
package Com.DR.AmoraDating

data class UserProfile(
    val id: String = "",
    val name: String = "",
    val age: Int = 24,
    val gender: String = "male",
    val city: String = "",
    val profession: String = "",
    val statusTag: String = "💖 Searching for Love",
    val bio: String = "",
    val photoUrl: String = "",
    val interests: List<String> = listOf("Music", "Travel"),
    val online: Boolean = true,
    // True for built-in sample profiles. These are NOT real users and are labelled as such in the UI.
    val demo: Boolean = false
)

data class ChatMessage(
    val id: String = "",
    val sender: String = "me",
    val text: String = "",
    val time: String = "Now",
    val liked: Boolean = false
)

object AmoraData {
    // Plug in your live Payment Gateway URL (Razorpay / Cashfree / Stripe) when ready
    const val PAYMENT_GATEWAY_URL = ""
    const val PLAN_PRICE_INR = 99
    const val FREE_MESSAGE_LIMIT = 5

    val STATUS_TAGS = listOf(
        "💖 Searching for Love",
        "🤝 Searching for Friends",
        "💑 In a Relationship",
        "✨ Happily Single",
        "💍 Ready for Commitment",
        "☕ Coffee & Casual Dates",
        "💬 Just Here to Chat",
        "✈️ Travel Partner"
    )

    val ALL_INTERESTS = listOf(
        "Music", "Travel", "Movies", "Coffee", "Cooking",
        "Fitness", "Books", "Photography", "Cricket", "Art", "Gaming", "Dance"
    )

    val SAMPLE_PROFILES: List<UserProfile> = listOf(
        UserProfile(
            id = "p1", name = "Ananya Sharma", age = 24, gender = "female",
            city = "Guwahati", profession = "Graphic Designer",
            statusTag = "💖 Searching for Love",
            bio = "Chai lover who enjoys mountain trips and genuine conversations.",
            photoUrl = "https://images.pexels.com/photos/16605844/pexels-photo-16605844.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Art", "Travel", "Music", "Coffee"), online = true
        ),
        UserProfile(
            id = "p2", name = "Aarav Verma", age = 26, gender = "male",
            city = "Delhi", profession = "Software Engineer",
            statusTag = "💍 Ready for Commitment",
            bio = "Coding, cricket, and late-night coffee. Looking for meaningful chats.",
            photoUrl = "https://images.pexels.com/photos/39474045/pexels-photo-39474045.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Cricket", "Coffee", "Movies", "Fitness"), online = true
        ),
        UserProfile(
            id = "p3", name = "Priya Nair", age = 23, gender = "female",
            city = "Bengaluru", profession = "Data Analyst",
            statusTag = "☕ Coffee & Casual Dates",
            bio = "Books, cafe hopping, and street photography are my favorite things.",
            photoUrl = "https://images.pexels.com/photos/39002915/pexels-photo-39002915.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Books", "Photography", "Coffee", "Travel"), online = true
        ),
        UserProfile(
            id = "p4", name = "Kabir Mehta", age = 27, gender = "male",
            city = "Mumbai", profession = "Music Producer",
            statusTag = "🤝 Searching for Friends",
            bio = "Playing guitar, evening walks by the sea, and making indie tracks.",
            photoUrl = "https://images.pexels.com/photos/18176286/pexels-photo-18176286.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Music", "Photography", "Movies", "Travel"), online = false
        ),
        UserProfile(
            id = "p5", name = "Riya Das", age = 22, gender = "female",
            city = "Kolkata", profession = "MBA Student",
            statusTag = "✨ Happily Single",
            bio = "Dance, street food, and classic Bollywood movies. Always smiling!",
            photoUrl = "https://images.pexels.com/photos/18451847/pexels-photo-18451847.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Dance", "Movies", "Cooking", "Music"), online = true
        ),
        UserProfile(
            id = "p6", name = "Rohan Joshi", age = 25, gender = "male",
            city = "Pune", profession = "Architect",
            statusTag = "✈️ Travel Partner",
            bio = "Trekking, cooking new recipes, and weekend road trips.",
            photoUrl = "https://images.pexels.com/photos/39264623/pexels-photo-39264623.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Travel", "Cooking", "Fitness", "Art"), online = true
        ),
        UserProfile(
            id = "p7", name = "Meera Rajput", age = 25, gender = "female",
            city = "Jaipur", profession = "Fashion Stylist",
            statusTag = "💑 In a Relationship",
            bio = "In love with art, colors, and Jaipur heritage.",
            photoUrl = "https://images.pexels.com/photos/26423890/pexels-photo-26423890.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Art", "Photography", "Travel", "Books"), online = false
        ),
        UserProfile(
            id = "p8", name = "Vihaan Singh", age = 24, gender = "male",
            city = "Chandigarh", profession = "Fitness Coach",
            statusTag = "💬 Just Here to Chat",
            bio = "Morning runs, gaming nights, and Punjabi playlists.",
            photoUrl = "https://images.pexels.com/photos/18304918/pexels-photo-18304918.jpeg?auto=compress&cs=tinysrgb&w=600",
            interests = listOf("Fitness", "Gaming", "Music", "Cricket"), online = true
        )
    ).map { it.copy(demo = true) }

    fun computeMatchScore(me: UserProfile, other: UserProfile): Int {
        var score = 70
        val shared = other.interests.count { it in me.interests }
        score += (shared * 6).coerceAtMost(18)
        if (other.statusTag == me.statusTag) score += 5
        if (other.online) score += 4
        if (me.city.isNotBlank() && other.city.equals(me.city, ignoreCase = true)) score += 5
        return score.coerceAtMost(99)
    }

    fun getOppositeGenderMatches(
        me: UserProfile,
        allProfiles: List<UserProfile>,
        blockedIds: Set<String>
    ): List<Pair<UserProfile, Int>> {
        val targetGender = when (me.gender) {
            "male" -> "female"
            "female" -> "male"
            else -> "all"
        }
        return allProfiles
            .filter { it.id !in blockedIds && it.id != me.id }
            .filter { targetGender == "all" || it.gender == targetGender }
            .map { it to computeMatchScore(me, it) }
            .sortedByDescending { it.second }
    }

    // Whole-word matching so ordinary words such as "cupid" or "hotpot" are not flagged
    private val SCAM_REGEX = Regex(
        "\\b(otp|upi|cvv|password|bank\\s*account|send\\s*money|paytm\\s*pin)\\b|bit\\.ly|https?://",
        RegexOption.IGNORE_CASE
    )

    fun containsScamPattern(text: String): Boolean = SCAM_REGEX.containsMatchIn(text)
}
AMORA_EOF

# 12. Create FirebaseRepo.kt
cat << 'AMORA_EOF' > app/src/main/java/Com/DR/AmoraDating/FirebaseRepo.kt
package Com.DR.AmoraDating

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

object FirebaseRepo {
    private const val PACKAGE_NAME = "Com.DR.AmoraDating"

    private fun authOrNull(): FirebaseAuth? = try {
        FirebaseAuth.getInstance()
    } catch (e: Exception) {
        null
    }

    private fun dbOrNull(): FirebaseFirestore? = try {
        FirebaseFirestore.getInstance()
    } catch (e: Exception) {
        null
    }

    val currentUid: String?
        get() = authOrNull()?.currentUser?.uid

    // Signs in anonymously and reports either the uid or a human-readable error.
    fun ensureSignedIn(onResult: (uid: String?, error: String?) -> Unit) {
        val auth = authOrNull()
        if (auth == null) {
            onResult(null, "Firebase is not configured: google-services.json was missing from this build.")
            return
        }
        val existing = auth.currentUser?.uid
        if (existing != null) {
            setOnlineStatus(true)
            onResult(existing, null)
            return
        }
        auth.signInAnonymously()
            .addOnSuccessListener { result ->
                setOnlineStatus(true)
                onResult(result.user?.uid, null)
            }
            .addOnFailureListener { e ->
                onResult(null, describeAuthError(e))
            }
    }

    private fun describeAuthError(e: Exception): String {
        val raw = e.localizedMessage ?: e.message ?: e.javaClass.simpleName
        return when {
            raw.contains("CONFIGURATION_NOT_FOUND", ignoreCase = true) ->
                "Firebase Authentication is not set up for this project (CONFIGURATION_NOT_FOUND). " +
                    "In the Fir
