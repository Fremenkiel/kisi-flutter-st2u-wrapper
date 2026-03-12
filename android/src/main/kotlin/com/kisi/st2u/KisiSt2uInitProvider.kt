package com.kisi.st2u

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import de.kisi.android.SecureUnlockConfiguration
import io.reactivex.rxjava3.core.Maybe

/**
 * ContentProvider that runs at process start — before any BroadcastReceiver fires.
 *
 * On a device reboot, the Kisi SDK's DeviceRebootReceiver fires before Flutter has
 * started, meaning SecureUnlockConfiguration.init() has never been called. This causes
 * a crash because MotionSenseSettings.preferences is uninitialized.
 *
 * This provider reads the persisted clientId (saved by KisiSt2uPlugin on first
 * initialize()) and calls SecureUnlockConfiguration.init() with a no-op login
 * callback so the SDK's preferences are initialized in time. The real login
 * callback is wired up when Flutter starts and initialize() is called again.
 */
internal class KisiSt2uInitProvider : ContentProvider() {

    override fun onCreate(): Boolean {
        val ctx = context ?: return false
        val clientId = ctx
            .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_CLIENT_ID, -1)

        // Always initialize — even with a default clientId of 0 — so that
        // MotionSenseSettings.preferences is never uninitialized when
        // DeviceRebootReceiver fires before Flutter starts. The real clientId
        // and login callback are supplied when Flutter calls initialize().
        SecureUnlockConfiguration.init(
            context = ctx,
            clientId = clientId.takeIf { it != -1 } ?: 0,
            fetchLoginCallback = { Maybe.empty() },
            onUnlockCompleteCallback = { _, _ -> },
        )
        return true
    }

    override fun query(uri: Uri, p: Array<String>?, s: String?, sA: Array<String>?, so: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, s: String?, sA: Array<String>?): Int = 0
    override fun update(uri: Uri, v: ContentValues?, s: String?, sA: Array<String>?): Int = 0

    internal companion object {
        const val PREFS_NAME = "kisi_st2u_prefs"
        const val KEY_CLIENT_ID = "client_id"
    }
}
