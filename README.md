# kisi_st2u

A Flutter plugin that wraps the Kisi Straight-to-Unlock (ST2U) native SDKs for iOS and Android, enabling NFC tap-to-unlock and BLE beacon proximity detection in your Flutter app.

| Feature | iOS | Android |
|---|---|---|
| NFC Tap-to-Unlock | ✅ | ✅ |
| BLE Beacon Monitoring | ✅ | ✅ |
| Proximity Proof (TOTP) | ✅ | ✅ |
| Motion Sense (hand wave) | ❌ | ✅ |
| Offline unlock cache | ✅ | ✅ |

---

## Requirements

| Platform | Minimum version |
|---|---|
| iOS | 13.0 |
| Android | 5.0 (API 21) |
| Flutter | 3.10+ |
| Dart | 3.0+ |

---

## Setup

The plugin requires native SDK binaries that are not bundled in the git repository. Download them by running the setup script **before** your first build:

```sh
sh scripts/setup.sh
```

Or pass explicit versions:

```sh
sh scripts/setup.sh --ios-tag 0.8.0 --android-version 0.16
```

This will:
- Clone the `SecureAccess.xcframework` from [`kisi-inc/kisi-ios-st2u-framework`](https://github.com/kisi-inc/kisi-ios-st2u-framework) into `ios/Frameworks/`
- Download `st2u-X.XX.aar` from [`kisi-inc/kisi-android-st2u-sdk-public`](https://github.com/kisi-inc/kisi-android-st2u-sdk-public/releases) into `android/libs/`

---

## iOS configuration

Add to your app's `Info.plist`:

```xml
<!-- Bluetooth (required for Tap-to-Unlock) -->
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Used to unlock doors via Kisi readers</string>
<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-peripheral</string>
</array>

<!-- Location (recommended: improves tap reliability and reader restrictions) -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Used to detect nearby Kisi readers</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to detect nearby Kisi readers</string>
```

Request permissions at runtime before calling `startTapToAccess()`:

```swift
// AppDelegate.swift or equivalent
CLLocationManager().requestAlwaysAuthorization()
```

---

## Android configuration

The SDK's AAR manifest automatically declares all required permissions. Your app must request these at runtime before calling `startMotionSense()`:

- `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` (Android 12+)
- `ACCESS_FINE_LOCATION`
- `POST_NOTIFICATIONS` (Android 13+)

For persistent Motion Sense, direct users to **Settings → Battery → Unrestricted** for your app.

---

## Usage

### 1. Initialize

Call `KisiSt2u.initialize()` once, before any other method (e.g., in `main()` or your app's root widget `initState`).

```dart
import 'package:kisi_st2u/kisi_st2u.dart';

await KisiSt2u.initialize(
  clientId: YOUR_CLIENT_ID, // Request from sdks@kisi.io
  loginProvider: (organizationId) async {
    // Return the stored login for this organization from your local cache.
    // The Kisi API provides id, token/secret, scram_credentials.phone_key,
    // and scram_credentials.online_certificate.
    return KisiLogin(
      id: myLogin.id,
      secret: myLogin.token,         // iOS: "token", Android: "secret"
      phoneKey: myLogin.phoneKey,    // iOS: "key",   Android: "phone_key"
      certificate: myLogin.cert,     // iOS: "certificate", Android: "online_certificate"
    );
  },
  onUnlockComplete: (result) {
    if (result.success) {
      print('Unlocked! source=${result.source}');
    } else {
      print('Unlock failed: ${result.errorCode}');
    }
  },
);
```

### 2. Start Tap-to-Unlock

```dart
await KisiSt2u.startTapToAccess();
```

### 3. Start beacon monitoring

```dart
await KisiSt2u.startReaderMonitoring();

// Call in foreground (better accuracy), stop in background (save battery):
// See AppLifecycleState.resumed / paused in the example app.
await KisiSt2u.startRanging();
```

### 4. Listen for events

```dart
// Unlock results
KisiSt2u.unlockStream.listen((result) { ... });

// Nearby beacons (use totp as proximity_proof in your API call)
KisiSt2u.beaconStream.listen((beacons) {
  for (final beacon in beacons) {
    print('Lock ${beacon.lockId} TOTP: ${beacon.totp}');
  }
});
```

### 5. Motion Sense (Android only)

```dart
if (Platform.isAndroid) {
  await KisiSt2u.setMotionSenseEnabled(true);
  try {
    await KisiSt2u.startMotionSense();
  } on MotionSenseStartException catch (e) {
    // e.failures contains strings like 'NO_BLE_SCAN_PERMISSION'
    print('Missing: ${e.failures}');
  }
}
```

### 6. iOS proximity proof for in-app unlocks

```dart
if (Platform.isIOS) {
  final proof = await KisiSt2u.getProximityProof(lockId);
  // Submit proof to your Kisi API unlock endpoint.
}
```

---

## KisiLogin field mapping

The `KisiLogin` model uses unified field names that map to each platform's native SDK:

| `KisiLogin` field | iOS `Login` field | Android `Login` field | Kisi API field |
|---|---|---|---|
| `id` | `id` | `id` | `id` |
| `secret` | `token` | `secret` | `token` |
| `phoneKey` | `key` | `phoneKey` | `scram_credentials.phone_key` |
| `certificate` | `certificate` | `onlineCertificate` | `scram_credentials.online_certificate` |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│                Flutter / Dart               │
│  KisiSt2u (static API)                      │
│  MethodChannelKisiSt2u (platform bridge)    │
└────────────────┬────────────────────────────┘
                 │  MethodChannel: com.kisi.st2u/methods
        ┌────────┴────────┐
        │                 │
┌───────▼──────┐  ┌───────▼──────────────┐
│  iOS Swift   │  │   Android Kotlin     │
│  SwiftKisiSt2│  │   KisiSt2uPlugin     │
│  uPlugin     │  │                      │
└──────┬───────┘  └──────┬───────────────┘
       │                 │
┌──────▼──────┐  ┌───────▼──────────────┐
│ SecureAccess│  │ Kisi ST2U AAR        │
│ .xcframework│  │ (SecureUnlock*)      │
└─────────────┘  └──────────────────────┘
```

---

## License

MIT. See [LICENSE](LICENSE).

The Kisi native SDKs have their own licenses — see:
- [kisi-ios-st2u-framework](https://github.com/kisi-inc/kisi-ios-st2u-framework)
- [kisi-android-st2u-sdk-public](https://github.com/kisi-inc/kisi-android-st2u-sdk-public)
