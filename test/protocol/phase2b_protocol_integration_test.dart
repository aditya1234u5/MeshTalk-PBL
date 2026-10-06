import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:bitmesh_chat/protocol/packet.dart';
import 'package:bitmesh_chat/protocol/packet_codec.dart';
import 'package:bitmesh_chat/protocol/packet_type.dart';
import 'package:bitmesh_chat/protocol/protocol_constants.dart';

void main() {
  test('Phase 2B message packet survives the codec boundary', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: ProtocolConstants.defaultTtl,
      timestampMs: 1720000000000,
      messageId: '11111111-1111-4111-8111-111111111111',
      senderId: '22222222-2222-4222-8222-222222222222',
      payload: Uint8List.fromList([1, 2, 3, 4, 5]),
      flags: ProtocolConstants.flagEncrypted |
          ProtocolConstants.flagRelayAllowed,
    );

    final wire = MeshPacketCodec.encode(packet);
    final decoded = MeshPacketCodec.decode(wire);

    expect(decoded, isNotNull);
    expect(decoded!.type, MeshPacketType.message);
    expect(decoded.ttl, ProtocolConstants.defaultTtl);
    expect(decoded.messageId, packet.messageId);
    expect(decoded.senderId, packet.senderId);
    expect(decoded.timestampMs, packet.timestampMs);
    expect(decoded.isEncrypted, isTrue);
    expect(decoded.relayAllowed, isTrue);
    expect(decoded.payload, orderedEquals(packet.payload));
  });

  test('Phase 2B relay decrements TTL without changing message identity', () {
    final packet = MeshProtocolPacket(
      type: MeshPacketType.message,
      ttl: 3,
      timestampMs: 1720000000000,
      messageId: '11111111-1111-4111-8111-111111111111',
      senderId: '22222222-2222-4222-8222-222222222222',
      payload: Uint8List.fromList([9, 8, 7]),
      flags: ProtocolConstants.flagEncrypted |
          ProtocolConstants.flagRelayAllowed,
    );

    final relayed = packet.decrementedForRelay();

    expect(relayed, isNotNull);
    expect(relayed!.ttl, 2);
    expect(relayed.messageId, packet.messageId);
    expect(relayed.senderId, packet.senderId);
    expect(relayed.timestampMs, packet.timestampMs);
  });
}
