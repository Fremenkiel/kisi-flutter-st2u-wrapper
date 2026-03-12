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
| Android | 5.0 (API 23) |
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

> **Note:** When this plugin is consumed as a `git:` dependency, Flutter resolves it into the pub cache rather than using your local clone. Run the setup script against the cached copy after `flutter pub get`:
> ```sh
> sh ~/.pub-cache/git/kisi-flutter-st2u-<hash>/scripts/setup.sh
> ```

### Using this plugin as a git dependency

When the host app references this plugin via a `git:` entry in `pubspec.yaml`, Flutter resolves it into the pub cache rather than using the local directory. The setup script must therefore be run against the **cached copy**, not the local clone. After `flutter pub get`, find the cached path and run setup from there:

```sh
# Find the cached plugin path
flutter pub deps | grep kisi_st2u
# or look in ~/.pub-cache/git/

# Run setup against the cached copy (replace the hash with the actual cache directory name)
sh ~/.pub-cache/git/kisi-flutter-st2u-<hash>/scripts/setup.sh
```

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
private let locationManager = CLLocationManager()

override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    locationManager.requestAlwaysAuthorization()
}
```

---

## Android configuration

The SDK's AAR manifest automatically declares all required permissions. Your app must request these at runtime before calling `startMotionSense()`:

- `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT` (Android 12+)
- `ACCESS_FINE_LOCATION`
- `POST_NOTIFICATIONS` (Android 13+)

For persistent Motion Sense, direct users to **Settings → Battery → Unrestricted** for your app.

### Repository setup

AGP requires the Kisi AAR to be served from a Maven repository (direct `.aar` file deps are forbidden when building a library AAR). The plugin uses a `local-maven` directory populated by `setup.sh`, but Gradle 8 does not propagate `allprojects { repositories {} }` from plugin subprojects into the host app. Add both JitPack and the local-maven path explicitly to your app's `android/build.gradle`:

```groovy
allprojects {
    repositories {
        google()
        mavenCentral()
        // Required for kisi_st2u transitive dependencies (blessed-android, luch)
        maven { url 'https://jitpack.io' }
        // Kisi ST2U local-maven — resolved dynamically from the pub cache
        def pubCacheDir = System.getenv('PUB_CACHE') ?: "${System.getProperty('user.home')}/.pub-cache"
        def kisiDir = new File("${pubCacheDir}/git").listFiles()?.find { it.name.startsWith('kisi-flutter-st2u-') }
        if (kisiDir) {
            maven { url "${kisiDir}/android/local-maven" }
        }
    }
}
```

After every `flutter pub get` or `flutter pub upgrade kisi_st2u`, re-run the setup script against the new pub-cache copy (the hash in the directory name changes with each update):

```sh
sh ~/.pub-cache/git/kisi-flutter-st2u-<hash>/scripts/setup.sh
```

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
