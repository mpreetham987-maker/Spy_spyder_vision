import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Connection lifecycle for the robot's Bluetooth link.
enum BtConnectionState { disconnected, scanning, connecting, connected, error }

/// Wraps `flutter_bluetooth_serial` to talk to the robot's Bluetooth
/// module (typically bridged through the Arduino Uno / ESP32).
///
/// Responsibilities:
///  • Discover and pair nearby devices
///  • Open/close a serial (SPP) connection
///  • Send plain-text command strings (`F`, `S1:90`, ...)
///  • Stream incoming status lines (`STATUS:BAT=...`) back to listeners
///
/// This class deliberately knows nothing about UI state — it only
/// exposes streams and futures. [RobotProvider] is the layer that
/// interprets what comes out of here.
class RobotBluetoothService {
  RobotBluetoothService();

  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSub;
  String _rxBuffer = '';

  final _stateController = StreamController<BtConnectionState>.broadcast();
  final _statusLineController = StreamController<String>.broadcast();
  final _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();

  BtConnectionState _state = BtConnectionState.disconnected;
  BluetoothDevice? connectedDevice;

  /// Current connection lifecycle state.
  Stream<BtConnectionState> get stateStream => _stateController.stream;

  /// Raw `STATUS:...` lines received from the robot firmware.
  Stream<String> get statusLines => _statusLineController.stream;

  /// Devices discovered during a scan (bonded + newly discovered).
  Stream<List<BluetoothDevice>> get discoveredDevices =>
      _devicesController.stream;

  BtConnectionState get state => _state;
  bool get isConnected => _state == BtConnectionState.connected;

  void _setState(BtConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  /// Confirms the adapter is on; on Android this also triggers the
  /// system permission prompts the plugin needs.
  Future<bool> ensureAdapterEnabled() async {
    final isEnabled = await _bluetooth.isEnabled ?? false;
    if (isEnabled) return true;
    final requested = await _bluetooth.requestEnable();
    return requested ?? false;
  }

  /// Scans for nearby + already-bonded devices. Bonded devices are
  /// emitted immediately; discovered ones stream in as they're found.
  Future<void> scanDevices({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _setState(BtConnectionState.scanning);
    final found = <String, BluetoothDevice>{};

    try {
      final bonded = await _bluetooth.getBondedDevices();
      for (final d in bonded) {
        found[d.address] = d;
      }
      _devicesController.add(found.values.toList());

      final discoverySub = _bluetooth.startDiscovery().listen((result) {
        found[result.device.address] = result.device;
        _devicesController.add(found.values.toList());
      });

      await Future.delayed(timeout);
      await discoverySub.cancel();
      await _bluetooth.cancelDiscovery();
    } catch (_) {
      // Discovery can fail silently on some platforms/emulators; the
      // already-bonded list (if any) still reaches the UI.
    } finally {
      if (_state == BtConnectionState.scanning) {
        _setState(BtConnectionState.disconnected);
      }
    }
  }

  /// Opens an SPP connection to [device] and starts listening for
  /// incoming data.
  Future<bool> connect(BluetoothDevice device) async {
    _setState(BtConnectionState.connecting);
    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      connectedDevice = device;

      _inputSub = connection.input?.listen(
        _handleIncomingBytes,
        onDone: () => _handleDisconnected(),
        onError: (_) => _handleDisconnected(),
      );

      _setState(BtConnectionState.connected);
      return true;
    } catch (_) {
      _setState(BtConnectionState.error);
      return false;
    }
  }

  void _handleIncomingBytes(Uint8List bytes) {
    _rxBuffer += utf8.decode(bytes, allowMalformed: true);

    // Firmware terminates each status packet with a newline.
    while (_rxBuffer.contains('\n')) {
      final index = _rxBuffer.indexOf('\n');
      final line = _rxBuffer.substring(0, index).trim();
      _rxBuffer = _rxBuffer.substring(index + 1);
      if (line.isNotEmpty) _statusLineController.add(line);
    }
  }

  void _handleDisconnected() {
    connectedDevice = null;
    _setState(BtConnectionState.disconnected);
  }

  /// Sends a raw command string terminated with a newline, matching the
  /// protocol the Arduino firmware expects (e.g. `F\n`, `S4:120\n`).
  Future<void> sendCommand(String command) async {
    final connection = _connection;
    if (connection == null || !connection.isConnected) return;
    connection.output.add(Uint8List.fromList(utf8.encode('$command\n')));
    await connection.output.allSent;
  }

  /// Sends several commands back-to-back (e.g. all 8 servo angles for a
  /// pose like "Stand" or "Sit").
  Future<void> sendCommands(List<String> commands) async {
    for (final c in commands) {
      await sendCommand(c);
    }
  }

  Future<void> disconnect() async {
    await _inputSub?.cancel();
    await _connection?.close();
    _connection = null;
    connectedDevice = null;
    _setState(BtConnectionState.disconnected);
  }

  Future<void> reconnect() async {
    final device = connectedDevice;
    await disconnect();
    if (device != null) await connect(device);
  }

  void dispose() {
    _inputSub?.cancel();
    _connection?.close();
    _stateController.close();
    _statusLineController.close();
    _devicesController.close();
  }
}
