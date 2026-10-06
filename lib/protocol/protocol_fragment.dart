import 'dart:typed_data';

/// Application-level fragmentation metadata.
///
/// This is different from the BLE transport fragment in
/// `lib/services/ble_fragment.dart`. BLE fragments carry arbitrary bytes over
/// GATT; protocol fragments carry one logical application message when its
/// payload itself is too large.
class ProtocolFragment {
  static const int headerLength = 21;

  ProtocolFragment({
    required this.transferId,
    required this.index,
    required this.total,
    required this.originalType,
    required Uint8List payload,
  }) : payload = Uint8List.fromList(payload) {
    if (transferId.length != 16) {
      throw ArgumentError('transferId must contain exactly 16 bytes');
    }
    if (total <= 0 || total > 0xFFFF) {
      throw ArgumentError('total must be 1..65535');
    }
    if (index < 0 || index >= total) {
      throw ArgumentError('index must be within total');
    }
    if (originalType < 0 || originalType > 0xFF) {
      throw ArgumentError('originalType must fit in one byte');
    }
  }

  final Uint8List transferId;
  final int index;
  final int total;
  final int originalType;
  final Uint8List payload;

  Uint8List encode() {
    final data = Uint8List(headerLength + payload.length);
    data.setRange(0, 16, transferId);
    data[16] = index >> 8;
    data[17] = index & 0xFF;
    data[18] = total >> 8;
    data[19] = total & 0xFF;
    data[20] = originalType;
    data.setRange(headerLength, data.length, payload);
    return data;
  }

  static ProtocolFragment? decode(Uint8List bytes) {
    if (bytes.length < headerLength) return null;

    final transferId = Uint8List.fromList(bytes.sublist(0, 16));
    final index = (bytes[16] << 8) | bytes[17];
    final total = (bytes[18] << 8) | bytes[19];
    final originalType = bytes[20];

    if (total == 0 || index >= total) return null;

    return ProtocolFragment(
      transferId: transferId,
      index: index,
      total: total,
      originalType: originalType,
      payload: Uint8List.fromList(bytes.sublist(headerLength)),
    );
  }
}
