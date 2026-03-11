/// The source of a completed unlock attempt.
enum KisiUnlockSource {
  /// NFC tap-to-unlock.
  nfc,

  /// Motion Sense (hand wave, Android only).
  motionSense,

  /// In-app unlock triggered by the user.
  inApp,
}

/// Error codes returned when an unlock attempt fails.
///
/// Error names match both platforms where applicable. Platform-specific
/// errors are noted in their documentation.
enum KisiUnlockErrorCode {
  // ── Shared ──────────────────────────────────────────────────────────────
  /// An unexpected command was received from the reader.
  unexpectedCommand,

  /// No login was available for the requested organization.
  missingLogin,

  /// Certificate fetch was denied (offline mode).
  certificateFetchDenied,

  /// The device screen lock is not enabled (required for 2FA).
  phoneLocked,

  // ── iOS-specific ─────────────────────────────────────────────────────
  /// The delegate is missing or not set.
  missingDelegate,

  /// Organization payload was invalid.
  orgInvalidPayload,

  /// Reader proof payload was invalid.
  readerProofInvalidPayload,

  /// Certificate payload was invalid.
  certificateInvalidPayload,

  /// Encryption failed.
  failedToEncrypt,

  /// Decryption failed.
  failedToDecrypt,

  /// SCRAM fetch error.
  scramFetchError,

  /// SCRAM fetch access denied.
  scramFetchDenied,

  /// SCRAM fetch has no network.
  scramFetchNoNetwork,

  /// Failed to verify reader proof.
  failedToVerifyReaderProof,

  /// Device owner verification is required (user needs to set up a passcode).
  needsDeviceOwnerVerification,

  /// Read offset out of bounds.
  offsetReadOutOfBounds,

  /// An unrecognized event was received.
  unrecognizedEvent,

  // ── Android-specific ─────────────────────────────────────────────────
  /// Reader proof validation failed.
  readerProofValidation,

  /// The phone is locked when 2FA requires it to be unlocked.
  phoneLockMissing,

  /// An unknown or unmapped error occurred.
  unknown,
}

/// Result of a completed unlock attempt (success or failure).
class KisiUnlockResult {
  /// Whether the unlock succeeded.
  final bool success;

  /// How the unlock was triggered. May be `null` on iOS (not provided by SDK).
  final KisiUnlockSource? source;

  /// Error code when [success] is `false`.
  final KisiUnlockErrorCode? errorCode;

  /// Raw error string from the native SDK for debugging.
  final String? rawError;

  /// Whether the unlock was performed online (iOS only).
  final bool? online;

  /// Duration of the unlock operation in seconds (iOS only).
  final double? duration;

  const KisiUnlockResult._({
    required this.success,
    this.source,
    this.errorCode,
    this.rawError,
    this.online,
    this.duration,
  });

  factory KisiUnlockResult.success({
    KisiUnlockSource? source,
    bool? online,
    double? duration,
  }) =>
      KisiUnlockResult._(
        success: true,
        source: source,
        online: online,
        duration: duration,
      );

  factory KisiUnlockResult.failure({
    KisiUnlockSource? source,
    required KisiUnlockErrorCode errorCode,
    String? rawError,
    double? duration,
  }) =>
      KisiUnlockResult._(
        success: false,
        source: source,
        errorCode: errorCode,
        rawError: rawError,
        duration: duration,
      );

  factory KisiUnlockResult.fromMap(Map<dynamic, dynamic> map) {
    final success = map['success'] as bool;
    final sourceStr = map['source'] as String?;
    final source = sourceStr == null ? null : _parseSource(sourceStr);
    final online = map['online'] as bool?;
    final duration = (map['duration'] as num?)?.toDouble();

    if (success) {
      return KisiUnlockResult.success(
        source: source,
        online: online,
        duration: duration,
      );
    } else {
      final rawError = map['errorCode'] as String?;
      return KisiUnlockResult.failure(
        source: source,
        errorCode: _parseError(rawError),
        rawError: rawError,
        duration: duration,
      );
    }
  }

  static KisiUnlockSource _parseSource(String source) {
    switch (source) {
      case 'nfc':
        return KisiUnlockSource.nfc;
      case 'motionSense':
        return KisiUnlockSource.motionSense;
      case 'inApp':
        return KisiUnlockSource.inApp;
      default:
        return KisiUnlockSource.nfc;
    }
  }

  static KisiUnlockErrorCode _parseError(String? error) {
    switch (error) {
      case 'UNEXPECTED_COMMAND':
      case 'unexpectedCommand':
        return KisiUnlockErrorCode.unexpectedCommand;
      case 'LOCAL_LOGIN_MISSING':
      case 'missingLogin':
        return KisiUnlockErrorCode.missingLogin;
      case 'CERTIFICATE_FETCH_DENIED':
      case 'certificateFetchDenied':
        return KisiUnlockErrorCode.certificateFetchDenied;
      case 'PHONE_LOCKED':
      case 'phoneLocked':
        return KisiUnlockErrorCode.phoneLocked;
      case 'missingDelegate':
        return KisiUnlockErrorCode.missingDelegate;
      case 'orgInvalidPayload':
        return KisiUnlockErrorCode.orgInvalidPayload;
      case 'readerProofInvalidPayload':
        return KisiUnlockErrorCode.readerProofInvalidPayload;
      case 'certificateInvalidPayload':
        return KisiUnlockErrorCode.certificateInvalidPayload;
      case 'failedToEncrypt':
        return KisiUnlockErrorCode.failedToEncrypt;
      case 'failedToDecrypt':
        return KisiUnlockErrorCode.failedToDecrypt;
      case 'scramFetchError':
        return KisiUnlockErrorCode.scramFetchError;
      case 'scramFetchDenied':
        return KisiUnlockErrorCode.scramFetchDenied;
      case 'scramFetchNoNetwork':
        return KisiUnlockErrorCode.scramFetchNoNetwork;
      case 'failedToVerifyReaderProof':
        return KisiUnlockErrorCode.failedToVerifyReaderProof;
      case 'needsDeviceOwnerVerification':
        return KisiUnlockErrorCode.needsDeviceOwnerVerification;
      case 'offsetReadOutOfBounds':
        return KisiUnlockErrorCode.offsetReadOutOfBounds;
      case 'unrecognizedEvent':
        return KisiUnlockErrorCode.unrecognizedEvent;
      case 'READER_PROOF_VALIDATION':
        return KisiUnlockErrorCode.readerProofValidation;
      case 'PHONE_LOCK_MISSING':
        return KisiUnlockErrorCode.phoneLockMissing;
      default:
        return KisiUnlockErrorCode.unknown;
    }
  }

  @override
  String toString() => success
      ? 'KisiUnlockResult.success(source: $source, online: $online, duration: ${duration?.toStringAsFixed(3)}s)'
      : 'KisiUnlockResult.failure(source: $source, errorCode: $errorCode)';
}
