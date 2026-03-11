import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:kisi_st2u/kisi_st2u.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Replace these with your real values.
// ─────────────────────────────────────────────────────────────────────────────
const int _kClientId = 0; // Request from sdks@kisi.io

/// Simulates fetching a stored login from your app's local cache or backend.
Future<KisiLogin?> _fetchLogin(int? organizationId) async {
  // In a real app, look up the login for [organizationId] from local storage
  // or your Kisi API session. Return null if the user is not logged in.
  return const KisiLogin(
    id: 123,
    secret: 'YOUR_LOGIN_TOKEN',
    phoneKey: 'YOUR_SCRAM_KEY',
    certificate: 'YOUR_ONLINE_CERTIFICATE',
  );
}
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(const KisiExampleApp());
}

class KisiExampleApp extends StatelessWidget {
  const KisiExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kisi ST2U Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  bool _initialized = false;
  bool _tapToAccessActive = false;
  bool _monitoringActive = false;
  bool _motionSenseEnabled = false;

  final List<String> _log = [];
  StreamSubscription<KisiUnlockResult>? _unlockSub;
  StreamSubscription<List<KisiBeacon>>? _beaconSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initSdk();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unlockSub?.cancel();
    _beaconSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_initialized) return;
    if (state == AppLifecycleState.resumed) {
      KisiSt2u.startRanging();
    } else if (state == AppLifecycleState.paused) {
      KisiSt2u.stopRanging();
    }
  }

  // ── SDK initialization ──────────────────────────────────────────────────

  Future<void> _initSdk() async {
    try {
      await KisiSt2u.initialize(
        clientId: _kClientId,
        loginProvider: _fetchLogin,
        onUnlockComplete: (result) => _addLog(result.toString()),
      );

      _unlockSub = KisiSt2u.unlockStream.listen(
        (result) => _addLog('Unlock: $result'),
      );
      _beaconSub = KisiSt2u.beaconStream.listen(
        (beacons) => _addLog('Beacons: ${beacons.map((b) => b.lockId).join(', ')}'),
      );

      setState(() => _initialized = true);
      _addLog('SDK initialized');
    } catch (e) {
      _addLog('Init error: $e');
    }
  }

  // ── Button actions ──────────────────────────────────────────────────────

  Future<void> _toggleTapToAccess() async {
    if (_tapToAccessActive) {
      await KisiSt2u.stopTapToAccess();
      setState(() => _tapToAccessActive = false);
      _addLog('Tap-to-unlock stopped');
    } else {
      await KisiSt2u.startTapToAccess();
      setState(() => _tapToAccessActive = true);
      _addLog('Tap-to-unlock started – hold device to a Kisi Reader');
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_monitoringActive) {
      await KisiSt2u.stopReaderMonitoring();
      setState(() => _monitoringActive = false);
      _addLog('Beacon monitoring stopped');
    } else {
      await KisiSt2u.startReaderMonitoring();
      await KisiSt2u.startRanging();
      setState(() => _monitoringActive = true);
      _addLog('Beacon monitoring started');
    }
  }

  Future<void> _toggleMotionSense() async {
    if (!Platform.isAndroid) {
      _addLog('Motion Sense is Android-only');
      return;
    }
    final next = !_motionSenseEnabled;
    await KisiSt2u.setMotionSenseEnabled(next);
    setState(() => _motionSenseEnabled = next);
    if (next) {
      try {
        await KisiSt2u.startMotionSense();
        _addLog('Motion Sense started');
      } on MotionSenseStartException catch (e) {
        _addLog('Motion Sense start failed: ${e.failures.join(', ')}');
      }
    } else {
      await KisiSt2u.stopMotionSense();
      _addLog('Motion Sense stopped');
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  void _addLog(String message) {
    setState(() {
      _log.insert(0, '[${DateTime.now().toIso8601String().substring(11, 19)}] $message');
      if (_log.length > 100) _log.removeLast();
    });
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kisi ST2U Example'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusBadge(ready: _initialized),
            const SizedBox(height: 16),
            _ActionButton(
              label: _tapToAccessActive
                  ? 'Stop Tap-to-Unlock'
                  : 'Start Tap-to-Unlock',
              icon: Icons.nfc,
              active: _tapToAccessActive,
              enabled: _initialized,
              onPressed: _toggleTapToAccess,
            ),
            const SizedBox(height: 8),
            _ActionButton(
              label: _monitoringActive
                  ? 'Stop Beacon Monitoring'
                  : 'Start Beacon Monitoring',
              icon: Icons.bluetooth_searching,
              active: _monitoringActive,
              enabled: _initialized,
              onPressed: _toggleMonitoring,
            ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 8),
              _ActionButton(
                label: _motionSenseEnabled
                    ? 'Stop Motion Sense'
                    : 'Start Motion Sense',
                icon: Icons.pan_tool,
                active: _motionSenseEnabled,
                enabled: _initialized,
                onPressed: _toggleMotionSense,
              ),
            ],
            const SizedBox(height: 16),
            const Text('Event log', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: ListView.builder(
                  itemCount: _log.length,
                  itemBuilder: (_, i) => Text(
                    _log[i],
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool ready;
  const _StatusBadge({required this.ready});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ready ? Icons.check_circle : Icons.pending,
          color: ready ? Colors.green : Colors.orange,
        ),
        const SizedBox(width: 8),
        Text(ready ? 'SDK ready' : 'Initializing…'),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: active
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: active
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
