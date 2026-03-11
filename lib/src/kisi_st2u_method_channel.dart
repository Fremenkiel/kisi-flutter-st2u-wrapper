import 'dart:async' show StreamController;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'kisi_st2u_platform_interface.dart';

/// Method channel implementation of [KisiSt2uPlatform].
///
/// Native -> Dart calls use the same channel (the platform side calls
/// `invokeMethod` on it and the Dart side handles them via
/// [setMethodCallHandler]).
class MethodChannelKisiSt2u extends KisiSt2uPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('com.kisi.st2u/methods');

  final _unlockController = StreamController<KisiUnlockResult>.broadcast();
  final _beaconController = StreamController<List<KisiBeacon>>.broadcast();

  Future<KisiLogin?> Function(int? organizationId)? _loginProvider;
  void Function(KisiUnlockResult)? _onUnlockComplete;

  MethodChannelKisiSt2u() {
    methodChannel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onUnlockSuccess':
        final map = Map<dynamic, dynamic>.from(call.arguments as Map);
        final result = KisiUnlockResult.fromMap({
          'success': true,
          ...map,
        });
        _unlockController.add(result);
        _onUnlockComplete?.call(result);

      case 'onUnlockFailure':
        final map = Map<dynamic, dynamic>.from(call.arguments as Map);
        final result = KisiUnlockResult.fromMap({
          'success': false,
          ...map,
        });
        _unlockController.add(result);
        _onUnlockComplete?.call(result);

      case 'onBeaconsDetected':
        final rawList = call.arguments as List;
        final beacons = rawList
            .map((e) => KisiBeacon.fromMap(Map<dynamic, dynamic>.from(e as Map)))
            .toList();
        _beaconController.add(beacons);

      case 'requestLogin':
        final args = Map<dynamic, dynamic>.from(call.arguments as Map);
        final requestId = args['requestId'] as String;
        final organizationId = args['organizationId'] as int?;

        final provider = _loginProvider;
        if (provider == null) {
          await methodChannel.invokeMethod('respondToLoginRequest', {
            'requestId': requestId,
            'login': null,
          });
          return;
        }

        final login = await provider(organizationId);
        await methodChannel.invokeMethod('respondToLoginRequest', {
          'requestId': requestId,
          'login': login?.toMap(),
        });

      default:
        throw MissingPluginException(
            'No handler for method ${call.method} on channel com.kisi.st2u/methods');
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────

  @override
  Future<void> initialize({
    required int clientId,
    required Future<KisiLogin?> Function(int? organizationId) loginProvider,
    void Function(KisiUnlockResult result)? onUnlockComplete,
  }) async {
    _loginProvider = loginProvider;
    _onUnlockComplete = onUnlockComplete;
    await methodChannel.invokeMethod('initialize', {'clientId': clientId});
  }

  // ── Tap-to-Unlock ─────────────────────────────────────────────────────

  @override
  Future<void> startTapToAccess() =>
      methodChannel.invokeMethod('startTapToAccess');

  @override
  Future<void> stopTapToAccess() =>
      methodChannel.invokeMethod('stopTapToAccess');

  // ── Beacon / Reader Monitoring ─────────────────────────────────────────

  @override
  Future<void> startReaderMonitoring() =>
      methodChannel.invokeMethod('startReaderMonitoring');

  @override
  Future<void> stopReaderMonitoring() =>
      methodChannel.invokeMethod('stopReaderMonitoring');

  @override
  Future<void> startRanging() =>
      methodChannel.invokeMethod('startRanging');

  @override
  Future<void> stopRanging() =>
      methodChannel.invokeMethod('stopRanging');

  @override
  Stream<List<KisiBeacon>> get beaconStream => _beaconController.stream;

  @override
  Stream<KisiUnlockResult> get unlockStream => _unlockController.stream;

  // ── iOS-specific ───────────────────────────────────────────────────────

  @override
  Future<bool> isNearbyLock(int lockId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('isNearbyLock is only supported on iOS.');
    }
    final result = await methodChannel.invokeMethod<bool>(
        'isNearbyLock', {'lockId': lockId});
    return result ?? false;
  }

  @override
  Future<int?> getProximityProof(int lockId) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      throw UnsupportedError('getProximityProof is only supported on iOS.');
    }
    return methodChannel.invokeMethod<int>(
        'getProximityProof', {'lockId': lockId});
  }

  // ── Android-specific ───────────────────────────────────────────────────

  @override
  Future<void> setMotionSenseEnabled(bool enabled) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('setMotionSenseEnabled is only supported on Android.');
    }
    await methodChannel
        .invokeMethod('setMotionSenseEnabled', {'enabled': enabled});
  }

  @override
  Future<void> startMotionSense() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('startMotionSense is only supported on Android.');
    }
    await methodChannel.invokeMethod('startMotionSense');
  }

  @override
  Future<void> stopMotionSense() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('stopMotionSense is only supported on Android.');
    }
    await methodChannel.invokeMethod('stopMotionSense');
  }
}
