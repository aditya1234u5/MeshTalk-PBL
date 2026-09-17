import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/mesh_packet.dart';
import '../models/peer.dart';
import 'encryption_service.dart';
import 'persistence_service.dart';

/// Custom GATT identifiers for the mesh chat service.
/// Every device runs BOTH roles at once:
///  - PERIPHERAL: advertises this service, accepts writes from central peers
///  - CENTRAL: scans for the service, connects, writes packets to peers
class MeshUuids {
  static const String serviceUuid = '7a4f2c10-9b3d-4e8a-8c1a-1a2b3c4d5e6f';
  static const String inboxCharacteristicUuid = '7a4f2c11-9b3d-4e8a-8c1a-1a2b3c4d5e6f';
}

/// Ties together the central role, peripheral role, per-peer encrypted
/// sessions, mesh relay logic (TTL decrement + seen-message dedup), and
/// local persistence into one service the UI layer consumes via
/// ChangeNotifier.
///
/// PLATFORM NOTE: simultaneous central+peripheral operation is supported on
/// Android without much fuss. On iOS, background peripheral/advertising has
/// real restrictions - budget time to test this specifically on iOS.
class BleMeshService extends ChangeNotifier {
  final EncryptionService encryption;
  final PersistenceService persistence;
  final String selfPeerId;
  String selfDisplayName;

  BleMeshService({
    required this.encryption,
    required this.persistence,
    required this.selfDisplayName,
  }) : selfPeerId = const Uuid().v4();

  final Map<String, Peer> _peers = {}; // peerId -> Peer (discovered/connected)
  final Map<String, BluetoothDevice> _connectedDevices = {}; // peerId -> live BLE device
  final Map<String, BluetoothCharacteristic> _outboxCharacteristics = {};
  final List<ChatMessage> _messages = [];
  final Set<String> _seenMessageIds = {}; // relay dedup cache, bounded below
  final List<String> _seenMessageOrder = [];
  static const int _maxSeenCache = 500;
  static const int defaultTtl = 6; // max relay hops

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isRunning = false;

  List<Peer> get peers => _peers.values.toList();
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isRunning => _isRunning;

  /// Direct (1-hop) neighbors only - this is what the topology view draws
  /// as "spokes" out of the self node. Multi-hop peers are only known
  /// indirectly (their messages arrive via a neighbor) so we don't claim
  /// to know the full mesh graph beyond one hop, which would be dishonest
  /// given flood-relay carries no routing/path information.
  List<Peer> get directNeighbors =>
      _peers.values.where((p) => p.linkState == PeerLinkState.connected).toList();

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _messages.addAll(persistence.loadAll());
    await _startPeripheral();
    await _startCentralScan();
    notifyListeners();
  }

  Future<void> stop() async {
    _isRunning = false;
    await _scanSub?.cancel();
    await FlutterBluePlus.stopScan();
    await FlutterBlePeripheral().stop();
    for (final device in _connectedDevices.values) {
      await device.disconnect();
    }
    _connectedDevices.clear();
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Peripheral role: advertise + accept incoming writes
  // ---------------------------------------------------------------------

  Future<void> _startPeripheral() async {
    final peripheral = FlutterBlePeripheral();
    final advertiseData = AdvertiseData(
      serviceUuid: MeshUuids.serviceUuid,
      localName: 'bm_${selfPeerId.substring(0, 8)}',
    );
    // NOTE: wire whatever "on write request" callback your installed
    // flutter_ble_peripheral version exposes to onPeripheralDataReceived()
    // below - see README "Peripheral GATT server wiring".
    await peripheral.start(advertiseData: advertiseData);
  }

  /// Called by the peripheral GATT server callback when a central peer
  /// writes bytes to our inbox characteristic. `fromPeerId` should be
  /// derived from the connecting central's identity by whatever the
  /// plugin's callback exposes (see README).
  void onPeripheralDataReceived(String fromPeerId, Uint8List bytes) {
    _handleIncomingBytes(fromPeerId, bytes);
  }

  // ---------------------------------------------------------------------
  // Central role: scan + connect + handshake + write
  // ---------------------------------------------------------------------

  Future<void> _startCentralScan() async {
    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName;
        if (name.startsWith('bm_')) {
          _registerDiscoveredPeer(r.device, name);
        }
      }
    });
    await FlutterBluePlus.startScan(
      withServices: [Guid(MeshUuids.serviceUuid)],
      continuousUpdates: true,
    );
  }

  Future<void> _registerDiscoveredPeer(BluetoothDevice device, String advertisedName) async {
    final shortId = advertisedName.replaceFirst('bm_', '');
    if (_peers.values.any((p) => p.peerId.startsWith(shortId))) return;

    final tempPeer = Peer(peerId: shortId, linkState: PeerLinkState.discovered);
    _peers[shortId] = tempPeer;
    notifyListeners();

    try {
      tempPeer.linkState = PeerLinkState.connecting;
      notifyListeners();
      await device.connect(timeout: const Duration(seconds: 10));
      final services = await device.discoverServices();
      final meshService = services.firstWhere(
        (s) => s.uuid.toString().toLowerCase() == MeshUuids.serviceUuid,
      );
      final inbox = meshService.characteristics.firstWhere(
        (c) => c.uuid.toString().toLowerCase() == MeshUuids.inboxCharacteristicUuid,
      );

      _connectedDevices[shortId] = device;
      _outboxCharacteristics[shortId] = inbox;

      // Perform the X25519 handshake before this peer is usable for chat.
      // Handshake packets travel with ttl=1 (never relayed further) and
      // an unencrypted payload (there's no session key yet to encrypt with).
      await _sendHandshake(shortId);

      tempPeer.linkState = PeerLinkState.connected;
      notifyListeners();

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          tempPeer.linkState = PeerLinkState.disconnected;
          _connectedDevices.remove(shortId);
          _outboxCharacteristics.remove(shortId);
          encryption.dropSession(shortId);
          notifyListeners();
        }
      });
    } catch (e) {
      tempPeer.linkState = PeerLinkState.disconnected;
      notifyListeners();
    }
  }

  Future<void> _sendHandshake(String peerId) async {
    final ourPublicKey = await encryption.ourPublicKeyBytes();
    final packet = MeshPacket(
      type: MeshPacket.typeHandshake,
      ttl: 1,
      msgId: const Uuid().v4(),
      senderId: selfPeerId,
      payload: ourPublicKey,
    );
    await _writeRaw(peerId, packet.toBytes());
  }

  Future<void> _writeRaw(String peerId, Uint8List bytes) async {
    final char = _outboxCharacteristics[peerId];
    if (char == null) return;
    const chunkSize = 180; // conservative pre-MTU-negotiation chunk size
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize < bytes.length) ? i + chunkSize : bytes.length;
      await char.write(bytes.sublist(i, end), withoutResponse: false);
    }
  }

  // ---------------------------------------------------------------------
  // Sending a chat message
  // ---------------------------------------------------------------------

  Future<void> sendMessage(String text) async {
    final msgId = const Uuid().v4();
    final payload = ChatPayload(
      senderName: selfDisplayName,
      text: text,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
    );
    final plaintext = payload.encode();

    _seenMessageIds.add(msgId);
    _seenMessageOrder.add(msgId);
    _trimSeenCache();

    final message = ChatMessage(
      id: msgId,
      senderId: selfPeerId,
      senderName: selfDisplayName,
      text: text,
      timestamp: DateTime.now(),
      isMine: true,
    );
    _messages.add(message);
    await persistence.saveMessage(message);
    notifyListeners();

    await _broadcastPlaintext(
      type: MeshPacket.typeChat,
      ttl: defaultTtl,
      msgId: msgId,
      senderId: selfPeerId,
      plaintext: plaintext,
    );
  }

  /// Encrypts the given plaintext separately for EACH connected peer (using
  /// that peer's own session key) and writes it to them individually - this
  /// is the hop-by-hop model described in encryption_service.dart.
  Future<void> _broadcastPlaintext({
    required int type,
    required int ttl,
    required String msgId,
    required String senderId,
    required Uint8List plaintext,
    String? excludePeerId,
  }) async {
    for (final peerId in _connectedDevices.keys) {
      if (peerId == excludePeerId) continue;
      if (!encryption.hasSession(peerId)) continue; // handshake not done yet
      final cipherText = await encryption.encryptFor(peerId, plaintext);
      final packet = MeshPacket(
        type: type,
        ttl: ttl,
        msgId: msgId,
        senderId: senderId,
        payload: cipherText,
      );
      await _writeRaw(peerId, packet.toBytes());
    }
  }

  // ---------------------------------------------------------------------
  // Receiving + relay logic
  // ---------------------------------------------------------------------

  Future<void> _handleIncomingBytes(String fromPeerId, Uint8List bytes) async {
    final packet = MeshPacket.fromBytes(bytes);
    if (packet == null) return; // malformed / not fully reassembled yet

    if (packet.type == MeshPacket.typeHandshake) {
      await encryption.establishSession(fromPeerId, packet.payload);
      return; // handshake packets are never relayed or de-duped as chat
    }

    if (_seenMessageIds.contains(packet.msgId)) return;
    _seenMessageIds.add(packet.msgId);
    _seenMessageOrder.add(packet.msgId);
    _trimSeenCache();

    final plaintext = await encryption.decryptFrom(fromPeerId, packet.payload);
    if (plaintext == null) return; // no session yet, or tampered - drop

    if (packet.type == MeshPacket.typeChat && packet.senderId != selfPeerId) {
      final chatPayload = ChatPayload.decode(plaintext);
      final message = ChatMessage(
        id: packet.msgId,
        senderId: packet.senderId,
        senderName: chatPayload.senderName,
        text: chatPayload.text,
        timestamp: DateTime.fromMillisecondsSinceEpoch(chatPayload.timestampMs),
        isMine: false,
      );
      _messages.add(message);
      await persistence.saveMessage(message);
      notifyListeners();
    }

    // Relay onward: re-encrypt with EACH other neighbor's own session key
    // (the plaintext is what's forwarded logically; each hop gets its own
    // ciphertext). TTL is decremented once per relay, not once per neighbor.
    if (packet.ttl > 1) {
      await _broadcastPlaintext(
        type: packet.type,
        ttl: packet.ttl - 1,
        msgId: packet.msgId,
        senderId: packet.senderId,
        plaintext: plaintext,
        excludePeerId: fromPeerId,
      );
    }
  }

  void _trimSeenCache() {
    while (_seenMessageOrder.length > _maxSeenCache) {
      final oldest = _seenMessageOrder.removeAt(0);
      _seenMessageIds.remove(oldest);
    }
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
