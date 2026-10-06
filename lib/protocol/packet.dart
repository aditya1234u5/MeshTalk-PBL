import 'dart:typed_data';

import 'packet_type.dart';
import 'protocol_constants.dart';

/// Immutable logical mesh packet.
///
/// This is the Phase 2 application-layer packet. It is intentionally separate
/// from BLE transport fragmentation:
///
///   MeshPacket -> binary codec -> BLE fragmenter -> BLE characteristic
///
/// A relay decrements [ttl] and forwards the same logical message ID.
class MeshProtocolPacket {
  MeshProtocolPacket({
    required this.type,
    required this.ttl,
    required this.timestampMs,
    required this.messageId,
    required this.senderId,
    required Uint8List payload,
    this.flags = ProtocolConstants.flagRelayAllowed,
  }) : payload = Uint8List.fromList(payload) {
    _validate();
  }

  final MeshPacketType type;
  final int ttl;
  final int timestampMs;
  final String messageId;
  final String senderId;
  final Uint8List payload;
  final int flags;

  bool get isEncrypted =>
      (flags & ProtocolConstants.flagEncrypted) != 0;

  bool get ackRequested =>
      (flags & ProtocolConstants.flagAckRequested) != 0;

  bool get relayAllowed =>
      (flags & ProtocolConstants.flagRelayAllowed) != 0;

  /// Creates the packet that a relay should forward.
  ///
  /// Returns null when the packet has no remaining relay budget.
  MeshProtocolPacket? decrementedForRelay() {
    if (!relayAllowed || ttl <= 1 || !type.isRelayable) return null;

    return MeshProtocolPacket(
      type: type,
      ttl: ttl - 1,
      timestampMs: timestampMs,
      messageId: messageId,
      senderId: senderId,
      payload: payload,
      flags: flags,
    );
  }

  MeshProtocolPacket copyWith({
    MeshPacketType? type,
    int? ttl,
    int? timestampMs,
    String? messageId,
    String? senderId,
    Uint8List? payload,
    int? flags,
  }) {
    return MeshProtocolPacket(
      type: type ?? this.type,
      ttl: ttl ?? this.ttl,
      timestampMs: timestampMs ?? this.timestampMs,
      messageId: messageId ?? this.messageId,
      senderId: senderId ?? this.senderId,
      payload: payload ?? this.payload,
      flags: flags ?? this.flags,
    );
  }

  void _validate() {
    if (ttl < 0 || ttl > ProtocolConstants.maxTtl) {
      throw ArgumentError.value(ttl, 'ttl', 'must be 0..${ProtocolConstants.maxTtl}');
    }
    if (messageId.length != 36 || senderId.length != 36) {
      throw ArgumentError('messageId and senderId must be UUID strings');
    }
    if (payload.length > ProtocolConstants.maxPayloadLength) {
      throw ArgumentError('payload is too large');
    }
    if (flags & ~ProtocolConstants.knownFlags != 0) {
      throw ArgumentError('unknown packet flags: 0x${flags.toRadixString(16)}');
    }
  }
}
