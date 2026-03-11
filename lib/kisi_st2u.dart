/// Flutter wrapper for the Kisi Straight-to-Unlock (ST2U) SDK.
///
/// Supports NFC tap-to-unlock on both iOS and Android, BLE beacon monitoring
/// for reader-restriction proximity proofs, and Motion Sense (Android only).
///
/// ## Quick start
///
/// ```dart
/// import 'package:kisi_st2u/kisi_st2u.dart';
///
/// await KisiSt2u.initialize(
///   clientId: YOUR_CLIENT_ID,
///   loginProvider: (organizationId) async {
///     return KisiLogin(
///       id: loginId,
///       secret: loginToken,
///       phoneKey: scramKey,
///       certificate: onlineCertificate,
///     );
///   },
///   onUnlockComplete: (result) {
///     if (result.success) print('Door unlocked!');
///   },
/// );
///
/// await KisiSt2u.startTapToAccess();
/// ```
library kisi_st2u;

import 'dart:io';

import 'src/kisi_st2u_method_channel.dart';
import 'src/kisi_st2u_platform_interface.dart';

export 'src/kisi_st2u_platform_interface.dart'
    show KisiSt2uPlatform, KisiLogin, KisiBeacon, KisiUnlockResult,
        KisiUnlockSource, KisiUnlockErrorCode;

/// Exception thrown when Motion Sense cannot be started due to missing
/// permissions or configuration.
class MotionSenseStartException implements Exception {
  /// Set of failure reason strings (e.g., `'NO_BLE_SCAN_PERMISSION'`).
  final Set<String> failures;

  const MotionSenseStartException(this.failures);

  @override
  String toString() => 'MotionSenseStartException: ${failures.join(', ')}';
}

/// Main entry point for the Kisi ST2U Flutter plugin.
///
/// All methods are static. Call [initialize] once (e.g., in `main()` or
/// your root widget's `initState`) before using any other methods.
class KisiSt2u {
  KisiSt2u._();

  static KisiSt2uPlatform? _platformInstance;

  static KisiSt2uPlatform get _platform {
    _platformInstance ??= MethodChannelKisiSt2u();
    return _platformInstance!;
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  /// Initializes the Kisi ST2U SDK.
  ///
  /// Must be called before any other methods.
  ///
  /// [clientId] – Your partner client ID. Request one from sdks@kisi.io.
  ///
  /// [loginProvider] – Called by the native SDK when it needs credentials
  /// for [organizationId]. Return a [KisiLogin] obtained from the Kisi API
  /// or your local cache, or `null` if no login is available for that org.
  ///
  /// [onUnlockComplete] – Optional callback invoked after each unlock attempt.
  /// You can also subscribe to [unlockStream] for the same events.
  static Future<void> initialize({
    required int clientId,
    required Future<KisiLogin?> Function(int? organizationId) loginProvider,
    void Function(KisiUnlockResult result)? onUnlockComplete,
  }) =>
      _platform.initialize(
        clientId: clientId,
        loginProvider: loginProvider,
        onUnlockComplete: onUnlockComplete,
      );

  // ── Tap-to-Unlock (NFC) ───────────────────────────────────────────────

  /// Starts the NFC tap-to-unlock session.
  ///
  /// Call this once when the app starts (after [initialize]).
  static Future<void> startTapToAccess() => _platform.startTapToAccess();

  /// Stops the NFC tap-to-unlock session.
  static Future<void> stopTapToAccess() => _platform.stopTapToAccess();

  // ── Reader / Beacon Monitoring ─────────────────────────────────────────

  /// Starts BLE beacon monitoring (background-safe).
  ///
  /// Call this once during app startup.
  static Future<void> startReaderMonitoring() =>
      _platform.startReaderMonitoring();

  /// Stops BLE beacon monitoring.
  static Future<void> stopReaderMonitoring() =>
      _platform.stopReaderMonitoring();

  /// Starts high-accuracy BLE ranging. Call when the app enters the foreground.
  ///
  /// On Android this is a no-op (ranging is handled internally).
  static Future<void> startRanging() => _platform.startRanging();

  /// Stops BLE ranging. Call when the app goes to the background to save battery.
  static Future<void> stopRanging() => _platform.stopRanging();

  /// Stream of [KisiBeacon] lists emitted as the device detects nearby readers.
  ///
  /// The [KisiBeacon.totp] value can be submitted as `proximity_proof` in
  /// your in-app unlock API call.
  static Stream<List<KisiBeacon>> get beaconStream => _platform.beaconStream;

  /// Stream of [KisiUnlockResult] events emitted after each unlock attempt.
  static Stream<KisiUnlockResult> get unlockStream => _platform.unlockStream;

  // ── iOS-specific ───────────────────────────────────────────────────────

  /// Returns `true` if the lock with [lockId] is currently nearby (iOS only).
  ///
  /// Throws [UnsupportedError] on Android.
  static Future<bool> isNearbyLock(int lockId) {
    _assertIOS('isNearbyLock');
    return _platform.isNearbyLock(lockId);
  }

  /// Returns the proximity proof (TOTP) for [lockId], or `null` if not nearby
  /// (iOS only).
  ///
  /// Throws [UnsupportedError] on Android.
  static Future<int?> getProximityProof(int lockId) {
    _assertIOS('getProximityProof');
    return _platform.getProximityProof(lockId);
  }

  // ── Android-specific ───────────────────────────────────────────────────

  /// Enables or disables Motion Sense (Android only).
  ///
  /// Motion Sense is disabled by default. Enable it before calling
  /// [startMotionSense].
  ///
  /// Throws [UnsupportedError] on iOS.
  static Future<void> setMotionSenseEnabled(bool enabled) {
    _assertAndroid('setMotionSenseEnabled');
    return _platform.setMotionSenseEnabled(enabled);
  }

  /// Starts the Motion Sense foreground service (Android only).
  ///
  /// Throws [MotionSenseStartException] if required permissions are missing.
  /// Throws [UnsupportedError] on iOS.
  static Future<void> startMotionSense() {
    _assertAndroid('startMotionSense');
    return _platform.startMotionSense();
  }

  /// Stops the Motion Sense foreground service (Android only).
  ///
  /// Throws [UnsupportedError] on iOS.
  static Future<void> stopMotionSense() {
    _assertAndroid('stopMotionSense');
    return _platform.stopMotionSense();
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  static void _assertIOS(String method) {
    if (!Platform.isIOS) {
      throw UnsupportedError('$method is only supported on iOS.');
    }
  }

  static void _assertAndroid(String method) {
    if (!Platform.isAndroid) {
      throw UnsupportedError('$method is only supported on Android.');
    }
  }
}
