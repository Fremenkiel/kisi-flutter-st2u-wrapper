package com.kisi.st2u

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.kisi.st2u.sdk.KisiBeaconTracker
import com.kisi.st2u.sdk.MotionSenseSettings
import com.kisi.st2u.sdk.MotionSenseStartException
import com.kisi.st2u.sdk.MotionSenseStarter
import com.kisi.st2u.sdk.SecureUnlockConfiguration
import com.kisi.st2u.sdk.SecureUnlockLogger
import com.kisi.st2u.sdk.model.Login
import com.kisi.st2u.sdk.model.UnlockError
import com.kisi.st2u.sdk.model.UnlockSource
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.reactivex.rxjava3.core.Maybe
import io.reactivex.rxjava3.core.MaybeEmitter
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

class KisiSt2uPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var appContext: Context
    private val mainHandler = Handler(Looper.getMainLooper())

    /** Emitters waiting for a login response from Dart, keyed by request ID. */
    private val pendingLoginRequests = ConcurrentHashMap<String, MaybeEmitter<Login>>()

    private var beaconTracker: KisiBeaconTracker? = null

    // ── FlutterPlugin ──────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.kisi.st2u/methods")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        beaconTracker?.stopRanging()
        beaconTracker = null
    }

    // ── MethodCallHandler (Dart → Native) ─────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            "initialize" -> {
                val clientId = call.argument<Int>("clientId")
                    ?: return result.error("INVALID_ARGS", "clientId is required", null)

                SecureUnlockConfiguration.init(
                    context = appContext,
                    clientId = clientId,
                    fetchLoginCallback = { organizationId ->
                        Maybe.create { emitter ->
                            val requestId = UUID.randomUUID().toString()
                            pendingLoginRequests[requestId] = emitter
                            mainHandler.post {
                                channel.invokeMethod(
                                    "requestLogin",
                                    mapOf(
                                        "requestId" to requestId,
                                        "organizationId" to organizationId,
                                    )
                                )
                            }
                        }
                    },
                    onUnlockCompleteCallback = { source, error ->
                        val sourceStr = when (source) {
                            UnlockSource.NFC -> "nfc"
                            UnlockSource.MOTION_SENSE -> "motionSense"
                            UnlockSource.IN_APP -> "inApp"
                        }
                        mainHandler.post {
                            if (error == UnlockError.NONE) {
                                channel.invokeMethod(
                                    "onUnlockSuccess",
                                    mapOf("source" to sourceStr)
                                )
                            } else {
                                channel.invokeMethod(
                                    "onUnlockFailure",
                                    mapOf(
                                        "source" to sourceStr,
                                        "errorCode" to error.name,
                                    )
                                )
                            }
                        }
                    }
                )
                result.success(null)
            }

            // NFC tap-to-unlock is activated automatically by SecureUnlockConfiguration
            // on Android. These methods exist for API symmetry with iOS.
            "startTapToAccess" -> result.success(null)
            "stopTapToAccess" -> result.success(null)

            "startReaderMonitoring" -> {
                startBeaconTrackerIfNeeded()
                beaconTracker?.startRanging()
                result.success(null)
            }

            "stopReaderMonitoring" -> {
                beaconTracker?.stopRanging()
                result.success(null)
            }

            // Ranging is handled inside KisiBeaconTracker on Android; these are
            // no-ops kept for API symmetry with iOS.
            "startRanging" -> result.success(null)
            "stopRanging" -> result.success(null)

            "respondToLoginRequest" -> {
                val requestId = call.argument<String>("requestId")
                    ?: return result.error("INVALID_ARGS", "requestId is required", null)

                val loginMap = call.argument<Map<String, Any>>("login")
                val emitter = pendingLoginRequests.remove(requestId)

                if (emitter != null) {
                    if (loginMap != null) {
                        val login = Login(
                            id = (loginMap["id"] as Number).toInt(),
                            secret = loginMap["secret"] as String,
                            phoneKey = loginMap["phoneKey"] as String,
                            onlineCertificate = loginMap["certificate"] as String,
                        )
                        emitter.onSuccess(login)
                    } else {
                        emitter.onComplete() // Empty Maybe → no login available
                    }
                }
                result.success(null)
            }

            "setMotionSenseEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                    ?: return result.error("INVALID_ARGS", "enabled is required", null)
                MotionSenseSettings.isEnabled = enabled
                result.success(null)
            }

            "startMotionSense" -> {
                try {
                    MotionSenseStarter.start()
                    result.success(null)
                } catch (e: MotionSenseStartException) {
                    val failureNames = e.failures.map { it.name }
                    result.error(
                        "MOTION_SENSE_START_FAILED",
                        "Motion Sense could not be started: ${failureNames.joinToString()}",
                        failureNames
                    )
                }
            }

            "stopMotionSense" -> {
                MotionSenseStarter.stop()
                result.success(null)
            }

            // iOS-only methods
            "isNearbyLock", "getProximityProof" ->
                result.error(
                    "UNSUPPORTED",
                    "${call.method} is not supported on Android",
                    null
                )

            else -> result.notImplemented()
        }
    }

    // ── Beacon Tracker ─────────────────────────────────────────────────────

    private fun startBeaconTrackerIfNeeded() {
        if (beaconTracker != null) return
        beaconTracker = KisiBeaconTracker(
            context = appContext,
            onScanFailure = { exception ->
                SecureUnlockLogger.log(exception)
            },
            onBeaconsDetected = { beacons ->
                val beaconList = beacons.map { beacon ->
                    mapOf(
                        "lockId" to beacon.lockId,
                        "totp" to beacon.totp,
                    )
                }
                mainHandler.post {
                    channel.invokeMethod("onBeaconsDetected", beaconList)
                }
            }
        )
    }
}
