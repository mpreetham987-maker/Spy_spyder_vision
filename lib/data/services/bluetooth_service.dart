import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

/// Connection lifecycle for the robot's Bluetooth link.
///
/// [permissionDenied] exists specifically so a missing/denied runtime
/// permission (Android 12+ requires BLUETOOTH_SCAN/BLUETOOTH_CONNECT
/// to be granted at runtime, not just declared in the manifest) shows
/// up as a normal, handleable state instead of an uncaught exception
/// from the native plugin — that uncaught exception was the actual
/// cause of the "crash on connect" bug.
enum BtConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  error,
  permissionDenied,
}

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
  /// Requests the runtime permissions Android 12+ requires before any
  /// Bluetooth API call is safe to make. Declaring BLUETOOTH_SCAN /
  /// BLUETOOTH_CONNECT in the manifest is necessary but not
  /// sufficient — without this explicit runtime grant, the native
  /// plugin throws a PlatformException the moment it's touched.
  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      // Pre-Android-12 devices gate discovery on location instead.
      Permission.locationWhenInUse,
    ].request();

    // Location is only required on older OS versions where the
    // Bluetooth-specific permissions above don't exist yet — Android
    // reports those as "denied" rather than granting them, so it's
    // deliberately excluded from this check.
    return statuses[Permission.bluetoothScan]!.isGranted &&
        statuses[Permission.bluetoothConnect]!.isGranted;
  }

  /// Opens the OS app-settings screen — the only way to recover once
  /// a permission has been permanently denied ("Don't ask again").
  Future<void> openPermissionSettings() => openAppSettings();

  Future<bool> ensureAdapterEnabled() async {
    try {
      final granted = await _ensurePermissions();
      if (!granted) {
        _setState(BtConnectionState.permissionDenied);
        return false;
      }

      final isEnabled = await _bluetooth.isEnabled ?? false;
      if (isEnabled) return true;

      final requested = await _bluetooth.requestEnable();
      return requested ?? false;
    } catch (_) {
      // Any native-side failure (adapter missing, plugin error, user
      // dismissed the enable prompt in a way the plugin doesn't
      // handle, etc.) becomes a normal error state instead of an
      // uncaught exception.
      _setState(BtConnectionState.error);
      return false;
    }
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
