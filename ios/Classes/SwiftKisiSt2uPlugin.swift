import Flutter
import UIKit
import SecureAccess
import CoreLocation
import CoreBluetooth

public class SwiftKisiSt2uPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel!
    private var clientId: Int = 0

    /// Continuations waiting for a login response from Dart.
    private var pendingLoginRequests: [String: CheckedContinuation<Login?, Never>] = [:]

    // MARK: - Registration

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.kisi.st2u/methods",
            binaryMessenger: registrar.messenger()
        )
        let instance = SwiftKisiSt2uPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Method call handler (Dart → Native)

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "initialize":
            guard let args = call.arguments as? [String: Any],
                  let id = args["clientId"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "clientId is required",
                                    details: nil))
                return
            }
            clientId = id
            TapToAccessManager.shared.delegate = self
            result(nil)

        case "startTapToAccess":
            TapToAccessManager.shared.start()
            result(nil)

        case "stopTapToAccess":
            TapToAccessManager.shared.stop()
            result(nil)

        case "startReaderMonitoring":
            ReaderManager.shared.startMonitoring()
            result(nil)

        case "stopReaderMonitoring":
            ReaderManager.shared.stopMonitoring()
            result(nil)

        case "startRanging":
            ReaderManager.shared.startRanging()
            result(nil)

        case "stopRanging":
            ReaderManager.shared.stopRanging()
            result(nil)

        case "isNearbyLock":
            guard let args = call.arguments as? [String: Any],
                  let lockId = args["lockId"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "lockId is required",
                                    details: nil))
                return
            }
            result(ReaderManager.shared.isNearbyLock(lockId))

        case "getProximityProof":
            guard let args = call.arguments as? [String: Any],
                  let lockId = args["lockId"] as? Int else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "lockId is required",
                                    details: nil))
                return
            }
            result(ReaderManager.shared.proximityProofForLock(lockId))

        case "respondToLoginRequest":
            guard let args = call.arguments as? [String: Any],
                  let requestId = args["requestId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS",
                                    message: "requestId is required",
                                    details: nil))
                return
            }
            let loginMap = args["login"] as? [String: Any]
            let login: Login? = loginMap.map { map in
                Login(
                    id: map["id"] as! Int,
                    token: map["secret"] as! String,
                    key: map["phoneKey"] as! String,
                    certificate: map["certificate"] as! String
                )
            }
            if let continuation = pendingLoginRequests.removeValue(forKey: requestId) {
                continuation.resume(returning: login)
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Helpers

    private func sendUnlockSuccess(online: Bool, duration: TimeInterval, source: String? = nil) {
        var args: [String: Any] = [
            "online": online,
            "duration": duration,
        ]
        if let source = source { args["source"] = source }
        channel.invokeMethod("onUnlockSuccess", arguments: args)
    }

    private func sendUnlockFailure(errorCode: String, duration: TimeInterval) {
        channel.invokeMethod("onUnlockFailure", arguments: [
            "errorCode": errorCode,
            "duration": duration,
        ])
    }
}

// MARK: - TapToAccessDelegate

extension SwiftKisiSt2uPlugin: TapToAccessDelegate {

    public func tapToAccessSuccess(online: Bool, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.sendUnlockSuccess(online: online, duration: duration)
        }
    }

    public func tapToAccessFailure(error: TapToAccessError, duration: TimeInterval) {
        DispatchQueue.main.async {
            self.sendUnlockFailure(
                errorCode: self.errorCode(for: error),
                duration: duration
            )
        }
    }

    public func tapToAccessClientID() async -> Int {
        return clientId
    }

    public func tapToAccessLoginForOrganization(_ organization: Int?) async -> Login? {
        let requestId = UUID().uuidString
        return await withCheckedContinuation { continuation in
            pendingLoginRequests[requestId] = continuation
            DispatchQueue.main.async {
                self.channel.invokeMethod("requestLogin", arguments: [
                    "requestId": requestId,
                    "organizationId": organization as Any,
                ])
            }
        }
    }

    // MARK: Error mapping

    private func errorCode(for error: TapToAccessError) -> String {
        switch error {
        case .invalidTransition:               return "invalidTransition"
        case .orgInvalidPayload:               return "orgInvalidPayload"
        case .missingLogin:                    return "missingLogin"
        case .readerProofInvalidPayload:       return "readerProofInvalidPayload"
        case .certificateInvalidPayload:       return "certificateInvalidPayload"
        case .failedToEncrypt:                 return "failedToEncrypt"
        case .failedToDecrypt:                 return "failedToDecrypt"
        case .scramFetchError:                 return "scramFetchError"
        case .scramFetchDenied:                return "scramFetchDenied"
        case .scramFetchNoNetwork:             return "scramFetchNoNetwork"
        case .failedToVerifyReaderProof:       return "failedToVerifyReaderProof"
        case .needsDeviceOwnerVerification:    return "needsDeviceOwnerVerification"
        case .unexpectedCommand:               return "unexpectedCommand"
        case .missingDelegate:                 return "missingDelegate"
        case .offsetReadOutOfBounds:           return "offsetReadOutOfBounds"
        case .unrecognizedEvent:               return "unrecognizedEvent"
        @unknown default:                      return "unknown"
        }
    }
}

// MARK: - ReaderManager beacon forwarding

extension SwiftKisiSt2uPlugin {
    /// Call this from your app delegate / scene delegate when beacons are detected
    /// (via NotificationCenter or by observing `ReaderManager.enteredBeaconsLocks`).
    ///
    /// The plugin listens to `ReaderManagerDidEnterNotification` automatically.
    @objc private func readerManagerDidEnter(_ notification: Notification) {
        let allBeacons: [[String: Any]] = ReaderManager.shared.enteredBeaconsLocks
            .values
            .flatMap { $0 }
            .map { beacon in
                ["lockId": beacon.id, "totp": beacon.oneTimePassword]
            }
        DispatchQueue.main.async {
            self.channel.invokeMethod("onBeaconsDetected", arguments: allBeacons)
        }
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(readerManagerDidEnter(_:)),
            name: .ReaderManagerDidEnterNotification,
            object: nil
        )
    }
}
