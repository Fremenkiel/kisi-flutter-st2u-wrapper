import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/kisi_beacon.dart';
import 'models/kisi_login.dart';
import 'models/kisi_unlock_result.dart';

export 'models/kisi_beacon.dart';
export 'models/kisi_login.dart';
export 'models/kisi_unlock_result.dart';

/// The interface that platform implementations must implement.
abstract class KisiSt2uPlatform extends PlatformInterface {
  KisiSt2uPlatform() : super(token: _token);

  static final Object _token = Object();

  static KisiSt2uPlatform? _instance;

  static KisiSt2uPlatform get instance {
    if (_instance == null) {
      throw StateError(
        'No KisiSt2uPlatform instance has been registered. '
        'Make sure you have imported the kisi_st2u package.',
      );
    }
    return _instance!;
  }

  static set instance(KisiSt2uPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ── Lifecycle ───────────────────────────────────────────────────────────

  /// Initializes the SDK with a [clientId] and a [loginProvider] callback.
  ///
  /// [clientId] is a partner identifier assigned by Kisi (sdks@kisi.io).
  /// [loginProvider] is called by the native SDK when it needs credentials for
  /// a specific organization. Return `null` if no login is available.
  Future<void> initialize({
    required int clientId,
    required Future<KisiLogin?> Function(int? organizationId) loginProvider,
    void Function(KisiUnlockResult result)? onUnlockComplete,
  });

  // ── Tap-to-Unlock (NFC) ─────────────────────────────────────────────────

  /// Starts the NFC tap-to-unlock session. Call once during app startup.
  Future<void> startTapToAccess();

  /// Stops the NFC tap-to-unlock session.
  Future<void> stopTapToAccess();

  // ── Reader / Beacon Monitoring (shared concept, platform-specific API) ──

  /// Starts BLE beacon monitoring (background-safe).
  ///
  /// On iOS this calls `ReaderManager.shared.startMonitoring()`.
  /// On Android this starts `KisiBeaconTracker`.
  Future<void> startReaderMonitoring();

  /// Stops BLE beacon monitoring.
  Future<void> stopReaderMonitoring();

  /// Starts BLE beacon ranging for accurate proximity (foreground only).
  ///
  /// iOS: calls `ReaderManager.shared.startRanging()`.
  /// Android: no-op (ranging is part of the tracker).
  Future<void> startRanging();

  /// Stops BLE beacon ranging. Call when the app goes to the background.
  Future<void> stopRanging();

  /// Stream of beacon lists detected by the BLE scanner.
  Stream<List<KisiBeacon>> get beaconStream;

  /// Stream of unlock results (success or failure).
  Stream<KisiUnlockResult> get unlockStream;

  // ── iOS-specific ────────────────────────────────────────────────────────

  /// Returns whether the given [lockId] is currently detected nearby.
  ///
  /// iOS only. Throws [UnsupportedError] on Android.
  Future<bool> isNearbyLock(int lockId);

  /// Returns the proximity proof (TOTP) for [lockId], or `null` if not nearby.
  ///
  /// iOS only. Throws [UnsupportedError] on Android.
  Future<int?> getProximityProof(int lockId);

  // ── Android-specific ────────────────────────────────────────────────────

  /// Enables or disables Motion Sense (BLE-based hand-wave unlock).
  ///
  /// Android only. Throws [UnsupportedError] on iOS.
  Future<void> setMotionSenseEnabled(bool enabled);

  /// Starts the Motion Sense foreground service.
  ///
  /// Android only. Throws [MotionSenseStartException] if required permissions
  /// are missing. Throws [UnsupportedError] on iOS.
  Future<void> startMotionSense();

  /// Stops the Motion Sense foreground service.
  ///
  /// Android only. Throws [UnsupportedError] on iOS.
  Future<void> stopMotionSense();
}
