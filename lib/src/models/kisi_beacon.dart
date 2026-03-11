/// A Kisi BLE beacon detected near the device.
///
/// Beacons are emitted when the device detects a nearby Kisi Reader via
/// Bluetooth Low Energy. The [totp] field can be submitted to the Kisi API
/// as `proximity_proof` to prove physical presence at the reader.
class KisiBeacon {
  /// The ID of the Kisi lock associated with this beacon.
  final int lockId;

  /// Time-based one-time password representing the proximity proof.
  /// Submit this as `proximity_proof` in your in-app unlock API call.
  final int totp;

  const KisiBeacon({
    required this.lockId,
    required this.totp,
  });

  factory KisiBeacon.fromMap(Map<dynamic, dynamic> map) => KisiBeacon(
        lockId: (map['lockId'] as num).toInt(),
        totp: (map['totp'] as num).toInt(),
      );

  @override
  String toString() => 'KisiBeacon(lockId: $lockId, totp: $totp)';
}
