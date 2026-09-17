import 'dart:convert';
import 'dart:typed_data';

/// Wire format for a single mesh packet.
///
/// BLE characteristics have small MTUs (~20 bytes default, up to ~500 if
/// negotiated). We keep the header tiny and let BleMeshService handle
/// chunking/reassembly of the payload for longer messages.
///
/// Layout (all big-endian):
/// [0]      version        (1 byte)
/// [1]      type           (1 byte)  0=chat 1=announce 2=ack
/// [2]      ttl            (1 byte)  hop budget, decremented on each relay
/// [3..18]  msgId          (16 bytes) uuid, used for relay de-dup
/// [19..34] senderId       (16 bytes) uuid of original sender
/// [35..36] payloadLength  (2 bytes)
/// [37..]   payload        (variable, UTF-8 JSON, encrypted at higher layer)
class MeshPacket {
  static const int version = 1;
  static const int headerLength = 37;

  final int type;
  int ttl;
  final String msgId;
  final String senderId;
  final Uint8List payload;

  MeshPacket({
    required this.type,
    required this.ttl,
    required this.msgId,
    required this.senderId,
    required this.payload,
  });

  static const int typeChat = 0;
  static const int typeAnnounce = 1;
  static const int typeAck = 2;
  static const int typeHandshake = 3; // carries our X25519 public key, unencrypted

  Uint8List toBytes() {
    final msgIdBytes = _uuidToBytes(msgId);
    final senderIdBytes = _uuidToBytes(senderId);
    final buffer = BytesBuilder();
    buffer.addByte(version);
    buffer.addByte(type);
    buffer.addByte(ttl);
    buffer.add(msgIdBytes);
    buffer.add(senderIdBytes);
    buffer.add([
      (payload.length >> 8) & 0xFF,
      payload.length & 0xFF,
    ]);
    buffer.add(payload);
    return buffer.toBytes();
  }

  static MeshPacket? fromBytes(Uint8List bytes) {
    if (bytes.length < headerLength) return null;
    final ver = bytes[0];
    if (ver != version) return null;
    final type = bytes[1];
    final ttl = bytes[2];
    final msgId = _bytesToUuid(bytes.sublist(3, 19));
    final senderId = _bytesToUuid(bytes.sublist(19, 35));
    final payloadLen = (bytes[35] << 8) | bytes[36];
    if (bytes.length < headerLength + payloadLen) return null;
    final payload = bytes.sublist(headerLength, headerLength + payloadLen);
    return MeshPacket(
      type: type,
      ttl: ttl,
      msgId: msgId,
      senderId: senderId,
      payload: Uint8List.fromList(payload),
    );
  }

  /// Returns a copy with ttl-1, or null if the packet has no hops left.
  MeshPacket? decremented() {
    if (ttl <= 1) return null;
    return MeshPacket(
      type: type,
      ttl: ttl - 1,
      msgId: msgId,
      senderId: senderId,
      payload: payload,
    );
  }

  static Uint8List _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  static String _bytesToUuid(List<int> bytes) {
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

/// Helper for encoding/decoding the chat payload before it goes into
/// MeshPacket.payload. Kept separate from encryption so EncryptionService
/// can wrap/unwrap this JSON blob as ciphertext.
class ChatPayload {
  final String senderName;
  final String text;
  final int timestampMs;

  ChatPayload({required this.senderName, required this.text, required this.timestampMs});

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode({
        'n': senderName,
        't': text,
        'ts': timestampMs,
      })));

  static ChatPayload decode(Uint8List bytes) {
    final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    return ChatPayload(
      senderName: map['n'] as String,
      text: map['t'] as String,
      timestampMs: map['ts'] as int,
    );
  }
}
