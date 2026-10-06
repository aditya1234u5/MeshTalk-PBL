import 'dart:typed_data';

class BleFragment {
  static const int version = 1;

  // Wire format:
  // [0]      version       (1 byte)
  // [1..16]  transfer ID   (16 bytes)
  // [17..18] fragment index (uint16, big-endian)
  // [19..20] total count    (uint16, big-endian)
  // [21..]   fragment data
  static const int headerSize = 21;

  final Uint8List transferId;
  final int index;
  final int total;
  final Uint8List data;

  BleFragment({
    required this.transferId,
    required this.index,
    required this.total,
    required this.data,
  }) {
    if (transferId.length != 16) {
      throw ArgumentError('transferId must contain exactly 16 bytes');
    }
    if (total <= 0 || total > 0xFFFF) {
      throw ArgumentError('total must be between 1 and 65535');
    }
    if (index < 0 || index >= total) {
      throw ArgumentError('index must be in range 0..total-1');
    }
  }

  Uint8List encode() {
    final out = BytesBuilder();

    out.addByte(version);
    out.add(transferId);

    out.add([
      (index >> 8) & 0xFF,
      index & 0xFF,
      (total >> 8) & 0xFF,
      total & 0xFF,
    ]);

    out.add(data);
    return out.toBytes();
  }

  static BleFragment? decode(Uint8List bytes) {
    if (bytes.length < headerSize) return null;
    if (bytes[0] != version) return null;

    final transferId = Uint8List.fromList(bytes.sublist(1, 17));
    final index = (bytes[17] << 8) | bytes[18];
    final total = (bytes[19] << 8) | bytes[20];

    if (total <= 0 || index >= total) return null;

    return BleFragment(
      transferId: transferId,
      index: index,
      total: total,
      data: Uint8List.fromList(bytes.sublist(headerSize)),
    );
  }
}
