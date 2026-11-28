#!/usr/bin/env bash
set -euo pipefail

echo "Creating Amora Dating App (applicationId Com.amoradatingapp) Native Android Project..."

# 1. Create required Android directory structure
mkdir -p app/src/main/java/Com/DR/AmoraDating
mkdir -p app/src/main/res/values
mkdir -p app/src/main/res/drawable

# A differently-cased source folder (app/src/main/java/com) is a stale copy of the sources generated below.
# Compiling both gives duplicate-class and syntax errors, so it is moved out of the source set (not deleted).
# On case-insensitive file systems "com" and "Com" are the same folder and nothing is moved.
if [ -d "app/src/main/java/com" ] && [ ! "app/src/main/java/com" -ef "app/src/main/java/Com" ]; then
    STALE_DIR="stale-sources-backup/com-$(date +%s)"
    mkdir -p stale-sources-backup
    mv app/src/main/java/com "$STALE_DIR"
    echo "Moved stale app/src/main/java/com to $STALE_DIR (it duplicated the generated sources)"
fi

# --- Firebase config: app/google-services.json -------------------------------------------------
# The Google Services plugin turns this file into the Firebase resources (google_app_id, API key, ...)
# that FirebaseInitProvider reads at startup. If the file is missing, stale or for another package,
# the app fails at runtime with "Default FirebaseApp is not initialized".
GS_APP_ID="1:791906002776:android:9b1c4aefa11897cbe1672d"
GS_PACKAGE="Com.amoradatingapp"

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
    "project_number": "791906002776",
    "project_id": "amora-dating-app-d7c8a",
    "storage_bucket": "amora-dating-app-d7c8a.firebasestorage.app"
  },
  "client": [
    {
      "client_info": {
        "mobilesdk_app_id": "1:791906002776:android:9b1c4aefa11897cbe1672d",
        "android_client_info": {
          "package_name": "Com.amoradatingapp"
        }
      },
      "oauth_client": [],
      "api_key": [
        {
          "current_key": "AIzaSyAxNqDRZBsdXjH71-qpqLYoWyxRTj3Og28"
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
    chmod 644 app/google-services.json
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
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.0" apply false
    id("com.google.gms.google-services") version "4.6.0" apply false
}
AMORA_EOF

# 5. Create app/build.gradle.kts
cat << 'AMORA_EOF' > app/build.gradle.kts
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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
        applicationId = "Com.amoradatingapp"
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

    buildFeatures {
        compose = true
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

// Firebase BoM 35 ships Kotlin 2.4 metadata, so the project needs Kotlin 2.3 or newer.
kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
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
    implementation(platform("com.google.firebase:firebase-bom:35.2.0"))
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
    private const val PACKAGE_NAME = "Com.amoradatingapp"

    private const val MSG_NO_CONFIG =
        "Firebase is not configured: google-services.json " +
            "was missing from this build."
    private const val MSG_AUTH_NOT_SET_UP =
        "Firebase Authentication is not set up for this project. " +
            "In the Firebase Console open Authentication, tap " +
            "Get started and enable the Anonymous sign-in provider."
    private const val MSG_ANON_DISABLED =
        "Anonymous sign-in is disabled. Enable it in the Firebase " +
            "Console under Authentication, Sign-in method."
    private const val MSG_API_KEY =
        "The Firebase API key was rejected. Check the key " +
            "restrictions in Google Cloud Console."
    private const val MSG_NETWORK =
        "No network connection. Tap Retry when you are back online."

    private fun authOrNull(): FirebaseAuth? {
        return try {
            FirebaseAuth.getInstance()
        } catch (e: Exception) {
            null
        }
    }

    private fun dbOrNull(): FirebaseFirestore? {
        return try {
            FirebaseFirestore.getInstance()
        } catch (e: Exception) {
            null
        }
    }

    val currentUid: String?
        get() = authOrNull()?.currentUser?.uid

    fun setOnlineStatus(isOnline: Boolean) {
        val uid = currentUid ?: return
        val db = dbOrNull() ?: return
        val data = hashMapOf(
            "online" to isOnline,
            "packageName" to PACKAGE_NAME,
            "lastSeen" to FieldValue.serverTimestamp()
        )
        db.collection("users").document(uid)
            .set(data, SetOptions.merge())
    }

    fun saveUserProfile(profile: UserProfile) {
        val uid = currentUid ?: return
        val db = dbOrNull() ?: return
        val map = hashMapOf(
            "id" to uid,
            "name" to profile.name,
            "age" to profile.age,
            "gender" to profile.gender,
            "city" to profile.city,
            "profession" to profile.profession,
            "statusTag" to profile.statusTag,
            "bio" to profile.bio,
            "interests" to profile.interests,
            "online" to true,
            "packageName" to PACKAGE_NAME,
            "updatedAt" to FieldValue.serverTimestamp()
        )
        db.collection("users").document(uid)
            .set(map, SetOptions.merge())
    }

    fun sendMessageToCloud(targetProfileId: String, message: ChatMessage) {
        val uid = currentUid ?: return
        val db = dbOrNull() ?: return
        val roomId = listOf(uid, targetProfileId).sorted().joinToString("_")
        val map = hashMapOf(
            "id" to message.id,
            "fromUid" to uid,
            "toProfileId" to targetProfileId,
            "text" to message.text,
            "time" to message.time,
            "packageName" to PACKAGE_NAME,
            "createdAt" to FieldValue.serverTimestamp()
        )
        db.collection("chats").document(roomId)
            .collection("messages").add(map)
    }

    fun reportUser(targetProfileId: String, reason: String) {
        val db = dbOrNull() ?: return
        val uid = currentUid ?: "anonymous"
        val map = hashMapOf(
            "reporterUid" to uid,
            "targetProfileId" to targetProfileId,
            "reason" to reason,
            "packageName" to PACKAGE_NAME,
            "createdAt" to FieldValue.serverTimestamp()
        )
        db.collection("reports").add(map)
    }

    private fun describeAuthError(e: Exception): String {
        val raw = e.localizedMessage ?: e.message ?: e.javaClass.simpleName
        if (raw.contains("CONFIGURATION_NOT_FOUND", ignoreCase = true)) {
            return MSG_AUTH_NOT_SET_UP
        }
        if (raw.contains("OPERATION_NOT_ALLOWED", ignoreCase = true)) {
            return MSG_ANON_DISABLED
        }
        if (raw.contains("API key", ignoreCase = true) ||
            raw.contains("API_KEY", ignoreCase = true)
        ) {
            return MSG_API_KEY
        }
        if (raw.contains("network", ignoreCase = true)) {
            return MSG_NETWORK
        }
        return "Cloud sign-in failed: " + raw
    }

    // Signs in anonymously and reports either the uid or an error message.
    fun ensureSignedIn(onResult: (String?, String?) -> Unit) {
        val auth = authOrNull()
        if (auth == null) {
            onResult(null, MSG_NO_CONFIG)
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
}
AMORA_EOF

# 13. Create AmoraViewModel.kt
cat << 'AMORA_EOF' > app/src/main/java/Com/DR/AmoraDating/AmoraViewModel.kt
package Com.DR.AmoraDating

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

enum class SendResult { SENT, EMPTY, SCAM, LIMIT }

class AmoraViewModel : ViewModel() {

    var onboarded by mutableStateOf(false)
        private set

    var me by mutableStateOf(UserProfile(id = "me"))
        private set

    // Empty when the cloud connection is healthy; otherwise a message shown in a banner
    var cloudMessage by mutableStateOf("Connecting to cloud...")
        private set

    // Only set this to true after you have verified a real payment on your own backend
    var isPremium by mutableStateOf(false)
        private set

    val blockedIds = mutableStateListOf<String>()
    val messages = mutableStateMapOf<String, List<ChatMessage>>()

    private val demoReplies = listOf(
        "Hey! Nice to meet you 😊",
        "That sounds fun! Tell me more.",
        "Haha, I like your vibe.",
        "What do you usually do on weekends?",
        "Interesting! I'd love to hear the story behind that."
    )

    init {
        connectCloud()
    }

    fun connectCloud() {
        cloudMessage = "Connecting to cloud..."
        FirebaseRepo.ensureSignedIn { uid, error ->
            cloudMessage = if (uid != null) "" else (error ?: "Cloud sync is unavailable.")
        }
    }

    fun completeOnboarding(profile: UserProfile) {
        me = profile.copy(id = FirebaseRepo.currentUid ?: "me")
        onboarded = true
        FirebaseRepo.saveUserProfile(me)
    }

    fun updateStatusTag(tag: String) {
        me = me.copy(statusTag = tag)
        FirebaseRepo.saveUserProfile(me)
    }

    fun matches(): List<Pair<UserProfile, Int>> =
        AmoraData.getOppositeGenderMatches(me, AmoraData.SAMPLE_PROFILES, blockedIds.toSet())

    fun conversations(): List<UserProfile> =
        AmoraData.SAMPLE_PROFILES.filter { it.id !in blockedIds && !messages[it.id].isNullOrEmpty() }

    fun freeMessagesLeft(profileId: String): Int {
        val sent = (messages[profileId] ?: emptyList()).count { it.sender == "me" }
        return (AmoraData.FREE_MESSAGE_LIMIT - sent).coerceAtLeast(0)
    }

    fun send(profile: UserProfile, text: String): SendResult {
        val clean = text.trim()
        if (clean.isEmpty()) return SendResult.EMPTY
        if (AmoraData.containsScamPattern(clean)) return SendResult.SCAM
        if (!isPremium && freeMessagesLeft(profile.id) <= 0) return SendResult.LIMIT

        val msg = ChatMessage(id = System.nanoTime().toString(), sender = "me", text = clean, time = now())
        append(profile.id, msg)

        if (profile.demo) {
            // Demo profiles are not real people, so nothing is sent to the cloud; replies are canned.
            viewModelScope.launch {
                delay(1200)
                val n = (messages[profile.id] ?: emptyList()).size
                append(
                    profile.id,
                    ChatMessage(
                        id = System.nanoTime().toString(),
                        sender = profile.id,
                        text = demoReplies[n % demoReplies.size],
                        time = now()
                    )
                )
            }
        } else {
            FirebaseRepo.sendMessageToCloud(profile.id, msg)
        }
        return SendResult.SENT
    }

    fun toggleLike(profileId: String, messageId: String) {
        messages[profileId] = (messages[profileId] ?: emptyList()).map {
            if (it.id == messageId) it.copy(liked = !it.liked) else it
        }
    }

    fun block(profileId: String) {
        if (profileId !in blockedIds) blockedIds.add(profileId)
    }

    fun unblockAll() {
        blockedIds.clear()
    }

    fun report(profileId: String, reason: String) {
        FirebaseRepo.reportUser(profileId, reason)
    }

    private fun append(profileId: String, msg: ChatMessage) {
        messages[profileId] = (messages[profileId] ?: emptyList()) + msg
    }

    private fun now(): String = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
}
AMORA_EOF

# 14. Create MainActivity.kt (complete native Jetpack Compose UI)
cat << 'AMORA_EOF' > app/src/main/java/Com/DR/AmoraDating/MainActivity.kt
package Com.DR.AmoraDating

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Call
import androidx.compose.material.icons.filled.CallEnd
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.MicOff
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    private val vm: AmoraViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            AmoraTheme {
                AmoraApp(vm)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        FirebaseRepo.setOnlineStatus(true)
    }

    override fun onStop() {
        FirebaseRepo.setOnlineStatus(false)
        super.onStop()
    }
}

// ---------------------------------------------------------------------------------------------
// Root navigation
// ---------------------------------------------------------------------------------------------

@Composable
fun AmoraApp(vm: AmoraViewModel) {
    var tab by rememberSaveable { mutableIntStateOf(0) }
    var chatWith by rememberSaveable { mutableStateOf<String?>(null) }
    var inCall by rememberSaveable { mutableStateOf(false) }

    BackHandler(enabled = vm.onboarded && chatWith != null) {
        if (inCall) inCall = false else chatWith = null
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(modifier = Modifier.fillMaxSize().statusBarsPadding()) {
            if (!vm.onboarded) {
                OnboardingScreen(vm)
            } else {
                val partner = AmoraData.SAMPLE_PROFILES.firstOrNull { it.id == chatWith }
                when {
                    partner != null && inCall -> CallScreen(partner) { inCall = false }
                    partner != null -> ChatScreen(
                        vm = vm,
                        profile = partner,
                        onBack = { chatWith = null },
                        onCall = { inCall = true }
                    )
                    else -> MainScreen(vm, tab, { tab = it }, { chatWith = it })
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Onboarding (18+ age gate and profile setup)
// ---------------------------------------------------------------------------------------------

@Composable
fun OnboardingScreen(vm: AmoraViewModel) {
    var name by rememberSaveable { mutableStateOf("") }
    var ageText by rememberSaveable { mutableStateOf("") }
    var gender by rememberSaveable { mutableStateOf("male") }
    var city by rememberSaveable { mutableStateOf("") }
    var profession by rememberSaveable { mutableStateOf("") }
    var statusTag by rememberSaveable { mutableStateOf(AmoraData.STATUS_TAGS.first()) }
    var bio by rememberSaveable { mutableStateOf("") }
    var interestsCsv by rememberSaveable { mutableStateOf("Music,Travel") }
    var confirmed by rememberSaveable { mutableStateOf(false) }

    val age = ageText.toIntOrNull() ?: 0
    val selectedInterests = interestsCsv.split(",").filter { it.isNotBlank() }
    val ageError = ageText.isNotEmpty() && age < 18
    val canContinue = name.isNotBlank() && age >= 18 && confirmed

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(20.dp)
            .navigationBarsPadding()
            .imePadding(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "Welcome to Amora",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Text(
            text = "Amora is for adults only (18+). Tell us a little about yourself.",
            style = MaterialTheme.typography.bodyMedium
        )

        OutlinedTextField(
            value = name,
            onValueChange = { name = it },
            label = { Text("Name") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = ageText,
            onValueChange = { ageText = it.filter { c -> c.isDigit() }.take(2) },
            label = { Text("Age") },
            singleLine = true,
            isError = ageError,
            supportingText = { if (ageError) Text("You must be 18 or older to use Amora.") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            modifier = Modifier.fillMaxWidth()
        )

        Text("I am", style = MaterialTheme.typography.labelLarge)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("male", "female", "other").forEach { g ->
                TagChip(g.replaceFirstChar { it.uppercase() }, gender == g) { gender = g }
            }
        }

        OutlinedTextField(
            value = city,
            onValueChange = { city = it },
            label = { Text("City") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )
        OutlinedTextField(
            value = profession,
            onValueChange = { profession = it },
            label = { Text("Profession") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth()
        )

        Text("Looking for", style = MaterialTheme.typography.labelLarge)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(AmoraData.STATUS_TAGS) { tag ->
                TagChip(tag, statusTag == tag) { statusTag = tag }
            }
        }

        Text("Interests", style = MaterialTheme.typography.labelLarge)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(AmoraData.ALL_INTERESTS) { tag ->
                TagChip(tag, tag in selectedInterests) {
                    val updated = if (tag in selectedInterests) selectedInterests - tag else selectedInterests + tag
                    interestsCsv = updated.joinToString(",")
                }
            }
        }

        OutlinedTextField(
            value = bio,
            onValueChange = { bio = it },
            label = { Text("About me") },
            maxLines = 4,
            modifier = Modifier.fillMaxWidth()
        )

        Row(verticalAlignment = Alignment.CenterVertically) {
            Checkbox(checked = confirmed, onCheckedChange = { confirmed = it })
            Text("I confirm that I am 18 years or older.", style = MaterialTheme.typography.bodyMedium)
        }

        Button(
            onClick = {
                vm.completeOnboarding(
                    UserProfile(
                        name = name.trim(),
                        age = age,
                        gender = gender,
                        city = city.trim(),
                        profession = profession.trim(),
                        statusTag = statusTag,
                        bio = bio.trim(),
                        interests = selectedInterests
                    )
                )
            },
            enabled = canContinue,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Start matching")
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Main tabs
// ---------------------------------------------------------------------------------------------

@Composable
fun MainScreen(
    vm: AmoraViewModel,
    tab: Int,
    onTab: (Int) -> Unit,
    onOpenChat: (String) -> Unit
) {
    Column(modifier = Modifier.fillMaxSize()) {
        Box(modifier = Modifier.weight(1f)) {
            when (tab) {
                0 -> DiscoverTab(vm, onOpenChat)
                1 -> ChatsTab(vm, onOpenChat)
                else -> ProfileTab(vm)
            }
        }
        NavigationBar {
            NavigationBarItem(
                selected = tab == 0,
                onClick = { onTab(0) },
                icon = { Icon(Icons.Filled.Explore, contentDescription = "Discover") },
                label = { Text("Discover") }
            )
            NavigationBarItem(
                selected = tab == 1,
                onClick = { onTab(1) },
                icon = { Icon(Icons.Filled.ChatBubble, contentDescription = "Chats") },
                label = { Text("Chats") }
            )
            NavigationBarItem(
                selected = tab == 2,
                onClick = { onTab(2) },
                icon = { Icon(Icons.Filled.Person, contentDescription = "Profile") },
                label = { Text("Profile") }
            )
        }
    }
}

@Composable
fun DiscoverTab(vm: AmoraViewModel, onOpenChat: (String) -> Unit) {
    var filter by rememberSaveable { mutableStateOf("All") }
    val all = vm.matches()
    val shown = if (filter == "All") all else all.filter { it.first.statusTag == filter }

    Column(modifier = Modifier.fillMaxSize()) {
        CloudBanner(vm)
        LazyRow(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(listOf("All") + AmoraData.STATUS_TAGS) { tag ->
                TagChip(tag, filter == tag) { filter = tag }
            }
        }
        if (shown.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("No profiles match this filter.", textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                items(shown, key = { it.first.id }) { (profile, score) ->
                    ProfileCard(profile, score) { onOpenChat(profile.id) }
                }
            }
        }
    }
}

@Composable
fun ChatsTab(vm: AmoraViewModel, onOpenChat: (String) -> Unit) {
    val convos = vm.conversations()
    Column(modifier = Modifier.fillMaxSize()) {
        CloudBanner(vm)
        if (convos.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize().padding(24.dp),
                contentAlignment = Alignment.Center
            ) {
                Text("No chats yet. Open a profile in Discover and say hi!", textAlign = TextAlign.Center)
            }
        } else {
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(convos, key = { it.id }) { p ->
                    Column {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onOpenChat(p.id) }
                                .padding(horizontal = 16.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Avatar(p.photoUrl, p.name, 48.dp)
                            Spacer(modifier = Modifier.width(12.dp))
                            Column {
                                Text(p.name, fontWeight = FontWeight.Bold)
                                Text(
                                    text = vm.messages[p.id]?.lastOrNull()?.text ?: "",
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                        HorizontalDivider()
                    }
                }
            }
        }
    }
}

@Composable
fun ProfileTab(vm: AmoraViewModel) {
    var showPaywall by remember { mutableStateOf(false) }
    val me = vm.me

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        CloudBanner(vm)

        Row(verticalAlignment = Alignment.CenterVertically) {
            Avatar("", me.name, 64.dp)
            Spacer(modifier = Modifier.width(14.dp))
            Column {
                Text("${me.name}, ${me.age}", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(
                    text = listOf(me.city, me.profession).filter { it.isNotBlank() }.joinToString(" • "),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }

        Text("My status", style = MaterialTheme.typography.labelLarge)
        LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            items(AmoraData.STATUS_TAGS) { tag ->
                TagChip(tag, me.statusTag == tag) { vm.updateStatusTag(tag) }
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                if (vm.isPremium) {
                    Text("Amora Premium is active", fontWeight = FontWeight.Bold)
                    Text("Unlimited messages.", style = MaterialTheme.typography.bodySmall)
                } else {
                    Text("Free plan", fontWeight = FontWeight.Bold)
                    Text(
                        "${AmoraData.FREE_MESSAGE_LIMIT} free messages per chat. Upgrade for unlimited messages.",
                        style = MaterialTheme.typography.bodySmall
                    )
                    Button(onClick = { showPaywall = true }) {
                        Text("Upgrade for ₹${AmoraData.PLAN_PRICE_INR}")
                    }
                }
            }
        }

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text("Stay safe", fontWeight = FontWeight.Bold)
                Text(
                    "Never share OTPs, UPI details, bank information or passwords. " +
                        "Report anyone who asks for money or behaves badly.",
                    style = MaterialTheme.typography.bodySmall
                )
            }
        }

        if (vm.blockedIds.isNotEmpty()) {
            TextButton(onClick = { vm.unblockAll() }) {
                Text("Unblock all (${vm.blockedIds.size})")
            }
        }
    }

    if (showPaywall) {
        PaywallDialog { showPaywall = false }
    }
}

// ---------------------------------------------------------------------------------------------
// Chat and call
// ---------------------------------------------------------------------------------------------

@Composable
fun ChatScreen(vm: AmoraViewModel, profile: UserProfile, onBack: () -> Unit, onCall: () -> Unit) {
    val context = LocalContext.current
    val msgs = vm.messages[profile.id] ?: emptyList()
    var input by rememberSaveable(profile.id) { mutableStateOf("") }
    var menuOpen by remember { mutableStateOf(false) }
    var showReport by remember { mutableStateOf(false) }
    var showPaywall by remember { mutableStateOf(false) }
    val listState = rememberLazyListState()

    LaunchedEffect(msgs.size) {
        if (msgs.isNotEmpty()) listState.animateScrollToItem(msgs.lastIndex)
    }

    fun doSend() {
        when (vm.send(profile, input)) {
            SendResult.SENT -> {
                input = ""
            }
            SendResult.SCAM -> {
                Toast.makeText(
                    context,
                    "For your safety, don't share OTPs, bank details, passwords or links.",
                    Toast.LENGTH_LONG
                ).show()
            }
            SendResult.LIMIT -> {
                showPaywall = true
            }
            SendResult.EMPTY -> {
            }
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
            Avatar(profile.photoUrl, profile.name, 40.dp)
            Spacer(modifier = Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(profile.name, fontWeight = FontWeight.Bold)
                Text(
                    text = if (profile.online) "Online" else "Offline",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            IconButton(onClick = onCall) {
                Icon(Icons.Filled.Call, contentDescription = "Call")
            }
            Box {
                IconButton(onClick = { menuOpen = true }) {
                    Icon(Icons.Filled.MoreVert, contentDescription = "More")
                }
                DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                    DropdownMenuItem(
                        text = { Text("Report") },
                        onClick = {
                            menuOpen = false
                            showReport = true
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("Block") },
                        onClick = {
                            menuOpen = false
                            vm.block(profile.id)
                            onBack()
                        }
                    )
                }
            }
        }
        HorizontalDivider()

        if (profile.demo) {
            Text(
                text = "Demo profile: this is not a real person and replies are automated.",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.tertiary,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 6.dp)
            )
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth(),
            contentPadding = PaddingValues(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            if (msgs.isEmpty()) {
                item {
                    Text(
                        text = "Say hi to ${profile.name}!",
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(24.dp)
                    )
                }
            }
            items(msgs, key = { it.id }) { m ->
                MessageBubble(m, m.sender == "me") { vm.toggleLike(profile.id, m.id) }
            }
        }

        if (!vm.isPremium) {
            Text(
                text = "${vm.freeMessagesLeft(profile.id)} free messages left in this chat",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp)
            )
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .navigationBarsPadding()
                .imePadding()
                .padding(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedTextField(
                value = input,
                onValueChange = { input = it },
                modifier = Modifier.weight(1f),
                placeholder = { Text("Type a message") },
                maxLines = 3
            )
            IconButton(onClick = { doSend() }) {
                Icon(
                    Icons.AutoMirrored.Filled.Send,
                    contentDescription = "Send",
                    tint = MaterialTheme.colorScheme.primary
                )
            }
        }
    }

    if (showReport) {
        AlertDialog(
            onDismissRequest = { showReport = false },
            title = { Text("Report ${profile.name}") },
            text = {
                Column {
                    listOf("Spam or scam", "Fake profile", "Harassment", "Inappropriate content").forEach { reason ->
                        TextButton(
                            onClick = {
                                vm.report(profile.id, reason)
                                showReport = false
                                Toast.makeText(context, "Report submitted.", Toast.LENGTH_SHORT).show()
                            }
                        ) {
                            Text(reason)
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = { TextButton(onClick = { showReport = false }) { Text("Cancel") } }
        )
    }

    if (showPaywall) {
        PaywallDialog { showPaywall = false }
    }
}

@Composable
fun MessageBubble(m: ChatMessage, mine: Boolean, onLike: () -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start
    ) {
        Column(horizontalAlignment = if (mine) Alignment.End else Alignment.Start) {
            Box(
                modifier = Modifier
                    .widthIn(max = 280.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (mine) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.surfaceVariant
                    )
                    .clickable(onClick = onLike)
                    .padding(horizontal = 12.dp, vertical = 8.dp)
            ) {
                Text(
                    text = m.text,
                    color = if (mine) MaterialTheme.colorScheme.onPrimary
                    else MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Text(
                text = if (m.liked) "❤ ${m.time}" else m.time,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
fun CallScreen(profile: UserProfile, onEnd: () -> Unit) {
    var seconds by remember { mutableIntStateOf(0) }
    var muted by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        while (true) {
            delay(1000)
            seconds++
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Avatar(profile.photoUrl, profile.name, 140.dp)
        Spacer(modifier = Modifier.height(20.dp))
        Text(profile.name, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
        Text(
            text = "Preview call  " + "%02d:%02d".format(seconds / 60, seconds % 60),
            style = MaterialTheme.typography.bodyMedium
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Voice calling is a preview. No audio is transmitted yet.",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
        Spacer(modifier = Modifier.height(40.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(32.dp)) {
            CircleButton(
                icon = if (muted) Icons.Filled.MicOff else Icons.Filled.Mic,
                description = if (muted) "Unmute" else "Mute",
                background = MaterialTheme.colorScheme.secondary
            ) { muted = !muted }
            CircleButton(
                icon = Icons.Filled.CallEnd,
                description = "End call",
                background = Color(0xFFDC2626),
                onClick = onEnd
            )
        }
    }
}

// ---------------------------------------------------------------------------------------------
// Shared building blocks
// ---------------------------------------------------------------------------------------------

@Composable
fun ProfileCard(profile: UserProfile, score: Int, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        shape = RoundedCornerShape(16.dp)
    ) {
        Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
            Avatar(profile.photoUrl, profile.name, 72.dp)
            Spacer(modifier = Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "${profile.name}, ${profile.age}",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    if (profile.online) {
                        Spacer(modifier = Modifier.width(8.dp))
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF22C55E))
                        )
                    }
                }
                Text(
                    text = "${profile.city} • ${profile.profession}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = profile.statusTag,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = profile.bio,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.bodySmall
                )
                Text(
                    text = profile.interests.joinToString(" · "),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (profile.demo) {
                    Text(
                        text = "Demo profile",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.tertiary
                    )
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = "$score%",
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
fun Avatar(url: String, name: String, size: Dp) {
    Box(
        modifier = Modifier
            .size(size)
            .clip(CircleShape)
            .background(MaterialTheme.colorScheme.primaryContainer),
        contentAlignment = Alignment.Center
    ) {
        // The initial stays visible if the photo is missing or fails to load
        Text(
            text = name.take(1).uppercase(),
            style = MaterialTheme.typography.titleLarge,
            color = MaterialTheme.colorScheme.onPrimaryContainer
        )
        if (url.isNotBlank()) {
            AsyncImage(
                model = url,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}

@Composable
fun TagChip(text: String, selected: Boolean, onClick: () -> Unit) {
    val bg = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant
    val fg = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Text(text = text, color = fg, fontSize = 13.sp)
    }
}

@Composable
fun CircleButton(icon: ImageVector, description: String, background: Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(64.dp)
            .clip(CircleShape)
            .background(background)
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center
    ) {
        Icon(imageVector = icon, contentDescription = description, tint = Color.White)
    }
}

@Composable
fun CloudBanner(vm: AmoraViewModel) {
    val msg = vm.cloudMessage
    if (msg.isNotEmpty()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(MaterialTheme.colorScheme.errorContainer)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = msg,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onErrorContainer
            )
            TextButton(onClick = { vm.connectCloud() }) {
                Text("Retry")
            }
        }
    }
}

@Composable
fun PaywallDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Filled.Lock, contentDescription = null) },
        title = { Text("Amora Premium") },
        text = {
            Text(
                "Unlimited messages for ₹${AmoraData.PLAN_PRICE_INR}. " +
                    "You have used your ${AmoraData.FREE_MESSAGE_LIMIT} free messages in this chat."
            )
        },
        confirmButton = {
            Button(
                onClick = {
                    openPayment(context)
                    onDismiss()
                }
            ) {
                Text("Upgrade")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Not now") }
        }
    )
}

private fun openPayment(context: Context) {
    val url = AmoraData.PAYMENT_GATEWAY_URL
    if (url.isBlank()) {
        Toast.makeText(context, "Payments are not set up yet.", Toast.LENGTH_SHORT).show()
        return
    }
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    } catch (e: Exception) {
        Toast.makeText(context, "Couldn't open the payment page.", Toast.LENGTH_SHORT).show()
    }
}
AMORA_EOF

# 15. Create .gitignore (only if the repository does not have one yet)
if [ ! -f ".gitignore" ]; then
    cat << 'AMORA_EOF' > .gitignore
.gradle/
build/
app/build/
local.properties
.idea/
*.iml
*.jks
*.keystore
.DS_Store
AMORA_EOF
fi

# 16. Generate the Gradle wrapper (Gradle 8.9 is required by AGP 8.7.2)
if [ ! -f "gradlew" ]; then
    if command -v gradle > /dev/null 2>&1; then
        WRAPPER_TMP="$(mktemp -d)"
        # Run from an empty directory so an older installed Gradle never has to configure this project
        if (cd "$WRAPPER_TMP" && gradle wrapper --gradle-version 8.9 --distribution-type bin > /dev/null 2>&1); then
            cp "$WRAPPER_TMP/gradlew" "$WRAPPER_TMP/gradlew.bat" .
            mkdir -p gradle
            cp -r "$WRAPPER_TMP/gradle/wrapper" gradle/
            chmod +x gradlew
            echo "Generated Gradle wrapper (Gradle 8.9)"
        else
            echo "WARNING: could not generate the Gradle wrapper automatically."
        fi
        rm -rf "$WRAPPER_TMP"
    else
        echo "WARNING: 'gradle' not found, so no Gradle wrapper was generated."
        echo "         Install Gradle 8.9+ or run: gradle wrapper --gradle-version 8.9"
    fi
fi

echo ""
echo "Amora Dating App project created."
echo "Build a debug APK with:  ./gradlew assembleDebug   (or: gradle assembleDebug)"
