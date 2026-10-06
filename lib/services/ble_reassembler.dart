import 'dart:typed_data';

import 'ble_fragment.dart';

class _TransferBuffer {
  final int total;
  final Map<int, Uint8List> fragments = {};

  _TransferBuffer(this.total);
}

class BleReassembler {
  static const Duration timeout = Duration(seconds: 15);
  static const int maxActiveTransfers = 128;

  final Map<String, _TransferBuffer> _buffers = {};
  final Map<String, DateTime> _timestamps = {};

  Uint8List? add(String peerId, Uint8List bytes) {
    final fragment = BleFragment.decode(bytes);
    if (fragment == null) return null;

    final transferId = fragment.transferId
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    final key = '$peerId:$transferId';

    final existing = _buffers[key];
    if (existing != null && existing.total != fragment.total) {
      _buffers.remove(key);
      _timestamps.remove(key);
      return null;
    }

    final buffer = existing ?? _TransferBuffer(fragment.total);

    if (existing == null && _buffers.length >= maxActiveTransfers) {
      _removeOldest();
    }

    _buffers[key] = buffer;
    buffer.fragments[fragment.index] = fragment.data;
    _timestamps[key] = DateTime.now();

    _cleanupExpired();

    if (buffer.fragments.length != buffer.total) {
      return null;
    }

    final output = BytesBuilder();

    for (var i = 0; i < buffer.total; i++) {
      final part = buffer.fragments[i];
      if (part == null) return null;
      output.add(part);
    }

    _buffers.remove(key);
    _timestamps.remove(key);

    return output.toBytes();
  }

  void _cleanupExpired() {
    final now = DateTime.now();
    final expired = <String>[];

    for (final entry in _timestamps.entries) {
      if (now.difference(entry.value) > timeout) {
        expired.add(entry.key);
      }
    }

    for (final key in expired) {
      _buffers.remove(key);
      _timestamps.remove(key);
    }
  }

  void _removeOldest() {
    if (_timestamps.isEmpty) return;

    final oldest = _timestamps.entries.reduce(
      (a, b) => a.value.isBefore(b.value) ? a : b,
    );

    _timestamps.remove(oldest.key);
    _buffers.remove(oldest.key);
  }

  void clear() {
    _buffers.clear();
    _timestamps.clear();
  }
}
