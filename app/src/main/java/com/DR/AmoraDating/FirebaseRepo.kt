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
