/// Constants for MeshTalk's application-layer mesh protocol.
///
/// Phase 2 deliberately keeps the existing Phase 1 BLE transport framing
/// separate from the application packet format. BLE fragmentation is handled
/// by ble_fragment.dart; this layer describes the logical packet carried by it.
class ProtocolConstants {
  ProtocolConstants._();

  /// Current MeshTalk application protocol version.
  static const int version = 1;

  /// Maximum hop budget supported by the protocol.
  static const int maxTtl = 7;

  /// Default hop budget for newly-created broadcast messages.
  static const int defaultTtl = maxTtl;

  /// Fixed-width UUID fields used by the current MeshTalk identity layer.
  ///
  /// Phase 3 will replace this with the persistent cryptographic peer ID
  /// scheme. Keeping it at 16 bytes now avoids breaking the existing app.
  static const int idLength = 16;

  /// UUID/message identifier length.
  static const int messageIdLength = 16;

  /// Timestamp width in milliseconds since Unix epoch.
  static const int timestampLength = 8;

  /// Payload length field width.
  static const int payloadLengthField = 2;

  /// Header:
  /// version(1) + type(1) + ttl(1) + flags(1) + timestamp(8) +
  /// messageId(16) + senderId(16) + payloadLength(2)
  static const int headerLength =
      1 + 1 + 1 + 1 + timestampLength + messageIdLength + idLength + 2;

  static const int maxPayloadLength = 0xFFFF;

  // Packet flags.
  static const int flagEncrypted = 1 << 0;
  static const int flagAckRequested = 1 << 1;
  static const int flagRelayAllowed = 1 << 2;

  static const int knownFlags =
      flagEncrypted | flagAckRequested | flagRelayAllowed;
}
