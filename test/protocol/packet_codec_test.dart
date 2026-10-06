import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitmesh_chat/protocol/packet.dart';
import 'package:bitmesh_chat/protocol/packet_codec.dart';
import 'package:bitmesh_chat/protocol/packet_type.dart';
import 'package:bitmesh_chat/protocol/protocol_constants.dart';

void main() {
  const messageId = '12345678-1234-5678-1234-567812345678';
  const senderId = '87654321-4321-8765-4321-876543218765';

  test('encodes and decodes a packet losslessly', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: 7,
      timestampMs: 1760000000000,
      messageId: messageId,
      senderId: senderId,
      flags: ProtocolConstants.flagRelayAllowed,
      payload: Uint8List.fromList([1, 2, 3, 4, 5]),
    );

    final encoded = MeshPacketCodec.encode(packet);
    final decoded = MeshPacketCodec.decode(encoded);

    expect(decoded, isNotNull);
    expect(decoded!.type, MeshPacketType.message);
    expect(decoded.ttl, 7);
    expect(decoded.timestampMs, 1760000000000);
    expect(decoded.messageId, messageId);
    expect(decoded.senderId, senderId);
    expect(decoded.payload, [1, 2, 3, 4, 5]);
  });

  test('rejects truncated packets', () {
    expect(
      MeshPacketCodec.decode(Uint8List(ProtocolConstants.headerLength - 1)),
      isNull,
    );
  });

  test('rejects payload length mismatch', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: 7,
      timestampMs: 1760000000000,
      messageId: messageId,
      senderId: senderId,
      payload: Uint8List.fromList([1, 2, 3]),
    );

    final encoded = MeshPacketCodec.encode(packet);
    final truncated = Uint8List.fromList(encoded.sublist(0, encoded.length - 1));

    expect(MeshPacketCodec.decode(truncated), isNull);
  });

  test('relay decrements TTL exactly once', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: 7,
      timestampMs: 1760000000000,
      messageId: messageId,
      senderId: senderId,
      payload: Uint8List(0),
    );

    final relayed = packet.decrementedForRelay();

    expect(relayed, isNotNull);
    expect(relayed!.ttl, 6);
    expect(relayed.messageId, packet.messageId);
  });

  test('TTL 1 cannot be relayed', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: 1,
      timestampMs: 1760000000000,
      messageId: messageId,
      senderId: senderId,
      payload: Uint8List(0),
    );

    expect(packet.decrementedForRelay(), isNull);
  });
}
