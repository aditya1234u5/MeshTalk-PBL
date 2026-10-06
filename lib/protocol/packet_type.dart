/// Logical packet types used by the MeshTalk application protocol.
///
/// These values are intentionally kept in one place so adding a new packet
/// type does not require changing the binary codec.
enum MeshPacketType {
  announce(0x01),
  leave(0x02),
  message(0x03),
  fragment(0x04),
  noiseHandshake(0x05),
  noiseEncrypted(0x06),
  courierEnvelope(0x07),
  requestSync(0x08),
  fileTransfer(0x09),
  ack(0x0A);

  const MeshPacketType(this.value);

  final int value;

  static MeshPacketType? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }

  bool get isRelayable =>
      this != MeshPacketType.ack && this != MeshPacketType.noiseHandshake;
}
