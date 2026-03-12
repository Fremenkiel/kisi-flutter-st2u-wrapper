package com.kisi.st2u

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import de.kisi.android.service.ble.start.MotionSenseStarter
import de.kisi.android.service.ble.start.MotionSenseStarter.MotionSenseStartException

/**
 * Safe replacement for the SDK's DeviceRebootReceiver.
 *
 * The SDK's DeviceRebootReceiver calls MotionSenseStarter.start() unconditionally
 * on BOOT_COMPLETED. If BLE or location permissions are not accessible at boot
 * time, start() throws MotionSenseStartException, which propagates uncaught and
 * crashes the process.
 *
 * This receiver does the same work but swallows MotionSenseStartException so
 * a boot-time permission gap never kills the app. Motion Sense will be started
 * normally the next time the user opens the app and calls startMotionSense().
 */
internal class KisiSafeDeviceRebootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            MotionSenseStarter.start()
        } catch (_: MotionSenseStartException) {
            // Permissions or BLE not yet available at boot — Motion Sense will
            // restart the next time the app is opened.
        }
    }
}
