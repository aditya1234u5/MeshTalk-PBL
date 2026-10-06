import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// A single incoming GATT write, with the real identity of whoever sent
/// it - unlike flutter_ble_peripheral's onDataReceived, which only ever
/// gave raw bytes.
class GattWrite {
  final String address;
  final Uint8List bytes;
  GattWrite({required this.address, required this.bytes});
}

/// Thin wrapper around the small custom native Android GATT peripheral in
/// android/app/.../MainActivity.kt. See that file for why this exists:
/// in short, Android's own BluetoothGattServerCallback gives you the
/// writing device directly, but flutter_ble_peripheral never surfaced it
/// to Dart - so we wrote our own minimal native peripheral that does.
class NativeGattBridge {
  static const _methods = MethodChannel('bitmesh/gatt_methods');
  static const _events = EventChannel('bitmesh/gatt_events');

  Stream<GattWrite>? _stream;

  Future<void> start() => _methods.invokeMethod('start');
  Future<void> stop() => _methods.invokeMethod('stop');

  Stream<GattWrite> get onWrite {
    _stream ??= _events.receiveBroadcastStream().map((event) {
      final map = Map<Object?, Object?>.from(event as Map);
      final address = map['address'] as String;
      final bytesList = (map['bytes'] as List).cast<int>();
      return GattWrite(address: address, bytes: Uint8List.fromList(bytesList));
    });
    return _stream!;
  }
}
