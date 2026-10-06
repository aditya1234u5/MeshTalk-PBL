import 'dart:convert';
import 'dart:typed_data';

import 'packet.dart';
import 'packet_type.dart';
import 'protocol_constants.dart';

/// Binary encoder/decoder for MeshTalk application packets.
///
/// All multi-byte integers are big-endian.
///
/// Wire layout:
///
///   0       version          1 byte
///   1       type             1 byte
///   2       ttl              1 byte
///   3       flags            1 byte
///   4..11   timestamp        8 bytes
///   12..27  message ID       16 bytes
///   28..43  sender ID        16 bytes
///   44..45  payload length   2 bytes
///   46..    payload          variable
class MeshPacketCodec {
  MeshPacketCodec._();

  static Uint8List encode(MeshProtocolPacket packet) {
    final payloadLength = packet.payload.length;
    final output = ByteData(ProtocolConstants.headerLength + payloadLength);

    output.setUint8(0, ProtocolConstants.version);
    output.setUint8(1, packet.type.value);
    output.setUint8(2, packet.ttl);
    output.setUint8(3, packet.flags);
    output.setInt64(4, packet.timestampMs, Endian.big);

    final messageId = _uuidToBytes(packet.messageId);
    final senderId = _uuidToBytes(packet.senderId);

    for (var i = 0; i < 16; i++) {
      output.setUint8(12 + i, messageId[i]);
      output.setUint8(28 + i, senderId[i]);
    }

    output.setUint16(44, payloadLength, Endian.big);

    final bytes = output.buffer.asUint8List();
    bytes.setRange(
      ProtocolConstants.headerLength,
      ProtocolConstants.headerLength + payloadLength,
      packet.payload,
    );
    return bytes;
  }

  /// Returns null for malformed, truncated, unsupported-version, or
  /// unknown-type packets.
  static MeshProtocolPacket? decode(Uint8List bytes) {
    if (bytes.length < ProtocolConstants.headerLength) return null;

    final data = ByteData.sublistView(bytes);
    if (data.getUint8(0) != ProtocolConstants.version) return null;

    final type = MeshPacketType.fromValue(data.getUint8(1));
    if (type == null) return null;

    final ttl = data.getUint8(2);
    if (ttl > ProtocolConstants.maxTtl) return null;

    final flags = data.getUint8(3);
    if (flags & ~ProtocolConstants.knownFlags != 0) return null;

    final timestampMs = data.getInt64(4, Endian.big);
    final payloadLength = data.getUint16(44, Endian.big);

    if (payloadLength > ProtocolConstants.maxPayloadLength) return null;
    if (bytes.length != ProtocolConstants.headerLength + payloadLength) {
      return null;
    }

    final messageId = _bytesToUuid(bytes.sublist(12, 28));
    final senderId = _bytesToUuid(bytes.sublist(28, 44));
    final payload = Uint8List.fromList(
      bytes.sublist(ProtocolConstants.headerLength),
    );

    try {
      return MeshProtocolPacket(
        type: type,
        ttl: ttl,
        timestampMs: timestampMs,
        messageId: messageId,
        senderId: senderId,
        payload: payload,
        flags: flags,
      );
    } on ArgumentError {
      return null;
    }
  }

  static Uint8List encodeText(String text) =>
      Uint8List.fromList(utf8.encode(text));

  static String decodeText(Uint8List bytes) => utf8.decode(bytes);

  static Uint8List _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    if (hex.length != 32) {
      throw FormatException('Invalid UUID: $uuid');
    }

    final result = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      result[i] = int.parse(
        hex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }
    return result;
  }

  static String _bytesToUuid(List<int> bytes) {
    if (bytes.length != 16) {
      throw FormatException('UUID requires 16 bytes');
    }

    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
