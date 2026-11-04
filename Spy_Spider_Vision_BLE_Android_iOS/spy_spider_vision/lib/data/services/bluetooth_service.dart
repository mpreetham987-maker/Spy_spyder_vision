import 'dart:async';
import 'dart:convert';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Nordic-UART-compatible BLE service used by the ESP32 firmware.
const String spiderServiceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
const String spiderRxUuid = '6e400002-b5a3-f393-e0a9-e50e24dcca9e';
const String spiderTxUuid = '6e400003-b5a3-f393-e0a9-e50e24dcca9e';

enum BtConnectionState { disconnected, scanning, connecting, connected, error, permissionDenied }

class RobotBleDevice {
  RobotBleDevice(this.device, this.name);
  final BluetoothDevice device;
  final String name;
  String get address => device.remoteId.str;
}

class RobotBluetoothService {
  RobotBluetoothService();

  final _stateController = StreamController<BtConnectionState>.broadcast();
  final _statusController = StreamController<String>.broadcast();
  final _devicesController = StreamController<List<RobotBleDevice>>.broadcast();
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<List<int>>? _notifySub;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  BluetoothDevice? _device;
  BluetoothCharacteristic? _rx;
  BluetoothCharacteristic? _tx;
  final Map<String, RobotBleDevice> _found = {};
  String _rxBuffer = '';
  BtConnectionState _state = BtConnectionState.disconnected;

  Stream<BtConnectionState> get stateStream => _stateController.stream;
  Stream<String> get statusLines => _statusController.stream;
  Stream<List<RobotBleDevice>> get discoveredDevices => _devicesController.stream;
  BtConnectionState get state => _state;
  bool get isConnected => _state == BtConnectionState.connected;
  RobotBleDevice? get connectedDevice => _device == null ? null : RobotBleDevice(_device!, _device!.platformName.isNotEmpty ? _device!.platformName : 'SPY-SPIDER');

  void _setState(BtConnectionState value) { _state = value; _stateController.add(value); }

  Future<bool> ensureAdapterEnabled() async {
    try {
      if (await FlutterBluePlus.isSupported == false) { _setState(BtConnectionState.error); return false; }
      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }
      return true;
    } catch (_) { _setState(BtConnectionState.permissionDenied); return false; }
  }

  Future<void> openPermissionSettings() async {
    // On iOS and Android the OS Bluetooth permission prompt is presented by the BLE plugin.
    await FlutterBluePlus.turnOn().catchError((_) {});
  }

  Future<void> scanDevices({Duration timeout = const Duration(seconds: 12)}) async {
    _setState(BtConnectionState.scanning);
    _found.clear();
    try {
      await _scanSub?.cancel();
      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final d = result.device;
          final name = d.platformName.isNotEmpty ? d.platformName : result.advertisementData.advName;
          if (name.isEmpty || (!name.toUpperCase().contains('SPY') && !name.toUpperCase().contains('SPIDER'))) continue;
          _found[d.remoteId.str] = RobotBleDevice(d, name);
        }
        _devicesController.add(_found.values.toList());
      });
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) { _setState(BtConnectionState.error); }
    finally {
      await _scanSub?.cancel(); _scanSub = null;
      if (_state == BtConnectionState.scanning) _setState(BtConnectionState.disconnected);
    }
  }

  Future<bool> connect(RobotBleDevice selected) async {
    _setState(BtConnectionState.connecting);
    try {
      _device = selected.device;
      await _device!.connect(timeout: const Duration(seconds: 15), autoConnect: false);
      try { await _device!.requestMtu(100); } catch (_) { /* iOS negotiates MTU automatically. */ }
      _connectionSub = _device!.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _rx = null; _tx = null; _setState(BtConnectionState.disconnected);
        }
      });
      final services = await _device!.discoverServices();
      BluetoothService? service;
      for (final candidate in services) { if (candidate.uuid == Guid(spiderServiceUuid)) { service = candidate; break; } }
      if (service == null) throw Exception('Spy Spider BLE service not found');
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid == Guid(spiderRxUuid)) _rx = characteristic;
        if (characteristic.uuid == Guid(spiderTxUuid)) _tx = characteristic;
      }
      if (_rx == null || _tx == null) throw Exception('BLE UART characteristics missing');
      await _tx!.setNotifyValue(true);
      _notifySub = _tx!.onValueReceived.listen(_handleIncomingBytes);
      _setState(BtConnectionState.connected);
      return true;
    } catch (_) {
      await _device?.disconnect().catchError((_) {});
      _device = null; _rx = null; _tx = null;
      _setState(BtConnectionState.error);
      return false;
    }
  }

  void _handleIncomingBytes(List<int> bytes) {
    _rxBuffer += utf8.decode(bytes, allowMalformed: true);
    while (_rxBuffer.contains('\n')) {
      final i = _rxBuffer.indexOf('\n');
      final line = _rxBuffer.substring(0, i).trim();
      _rxBuffer = _rxBuffer.substring(i + 1);
      if (line.isNotEmpty) _statusController.add(line);
    }
  }

  Future<void> sendCommand(String command) async {
    final characteristic = _rx;
    if (characteristic == null || !isConnected) return;
    await characteristic.write(utf8.encode('$command\n'), withoutResponse: false);
  }

  Future<void> sendCommands(List<String> commands) async {
    for (final command in commands) { await sendCommand(command); }
  }

  Future<void> disconnect() async {
    await _notifySub?.cancel(); _notifySub = null;
    await _connectionSub?.cancel(); _connectionSub = null;
    final d = _device; _device = null; _rx = null; _tx = null;
    if (d != null) await d.disconnect();
    _setState(BtConnectionState.disconnected);
  }

  Future<void> reconnect() async {
    final d = connectedDevice;
    if (d == null) return;
    await disconnect();
    await connect(d);
  }

  void dispose() {
    _scanSub?.cancel(); _notifySub?.cancel(); _connectionSub?.cancel();
    _device?.disconnect();
    _stateController.close(); _statusController.close(); _devicesController.close();
  }
}
