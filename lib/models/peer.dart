enum PeerLinkState { discovered, connecting, connected, disconnected }

class Peer {
  final String peerId; // ephemeral random id, regenerated per session
  String displayName;
  PeerLinkState linkState;
  DateTime lastSeen;
  final bool isDirect; // true if we have a live BLE connection, false if known only via relay

  Peer({
    required this.peerId,
    this.displayName = 'unknown',
    this.linkState = PeerLinkState.discovered,
    DateTime? lastSeen,
    this.isDirect = false,
  }) : lastSeen = lastSeen ?? DateTime.now();
}
