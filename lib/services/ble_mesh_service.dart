import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/message.dart';
import '../models/mesh_packet.dart';
import '../models/peer.dart';
import '../protocol/packet.dart';
import '../protocol/packet_codec.dart';
import '../protocol/packet_type.dart';
import '../protocol/protocol_constants.dart';
import 'ble_fragment.dart';
import 'ble_reassembler.dart';
import 'encryption_service.dart';
import 'native_gatt_bridge.dart';
import 'persistence_service.dart';

/// Custom GATT identifiers for the mesh chat service.
class MeshUuids {
  static const String serviceUuid =
      '7a4f2c10-9b3d-4e8a-8c1a-1a2b3c4d5e6f';
  static const String inboxCharacteristicUuid =
      '7a4f2c11-9b3d-4e8a-8c1a-1a2b3c4d5e6f';
}

/// BLE mesh service.
///
/// Phase 2B connects the application protocol to the reliable Phase 1 BLE
/// transport:
///
///   MeshProtocolPacket -> MeshPacketCodec -> BLE fragments -> GATT
///   GATT -> BLE reassembly -> MeshPacketCodec -> MeshProtocolPacket
///
/// The existing hop-by-hop encryption service remains in place. The protocol
/// layer now owns packet type, TTL, timestamp, flags, IDs and binary framing.
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

  final Map<String, Peer> _peers = {};
  final Map<String, BluetoothDevice> _connectedDevices = {};
  final Map<String, BluetoothCharacteristic> _outboxCharacteristics = {};
  final Map<String, int> _peerMtu = {};

  final Map<String, Future<void>> _writeQueues = {};
  final Set<String> _connectingPeers = {};

  final List<ChatMessage> _messages = [];
  final Set<String> _seenMessageIds = {};
  final List<String> _seenMessageOrder = [];

  final Map<String, DateTime> _lastReconnectAttempt = {};

  final BleReassembler _reassembler = BleReassembler();

  static const int _maxSeenCache = 500;
  static const int defaultTtl = ProtocolConstants.defaultTtl;

  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _isRunning = false;

  List<Peer> get peers => _peers.values.toList();
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isRunning => _isRunning;

  List<Peer> get directNeighbors => _peers.values
      .where((p) => p.linkState == PeerLinkState.connected)
      .toList();

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

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

    await _peripheralDataSub?.cancel();
    _peripheralDataSub = null;

    await _scanSub?.cancel();
    _scanSub = null;

    await FlutterBluePlus.stopScan();
    await _nativeGatt.stop();

    final devices = List<BluetoothDevice>.from(_connectedDevices.values);

    for (final device in devices) {
      try {
        await device.disconnect();
      } catch (_) {}
    }

    _connectedDevices.clear();
    _outboxCharacteristics.clear();
    _peerMtu.clear();
    _writeQueues.clear();
    _connectingPeers.clear();
    _reassembler.clear();

    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Peripheral
  // -------------------------------------------------------------------------

  final _nativeGatt = NativeGattBridge();
  StreamSubscription<GattWrite>? _peripheralDataSub;

  Future<void> _startPeripheral() async {
    debugPrint(
      '[bitmesh] starting native peripheral, '
      'service=${MeshUuids.serviceUuid}',
    );

    try {
      await _nativeGatt.start();
      debugPrint('[bitmesh] native peripheral started');
    } catch (e, st) {
      debugPrint('[bitmesh] native peripheral start failed: $e');
      debugPrint('$st');
    }

    await _peripheralDataSub?.cancel();

    _peripheralDataSub = _nativeGatt.onWrite.listen((write) {
      debugPrint(
        '[bitmesh] write from ${write.address}: '
        '${write.bytes.length} bytes',
      );

      onPeripheralDataReceived(write.address, write.bytes);
    });
  }

  void onPeripheralDataReceived(
    String fromPeerId,
    Uint8List bytes,
  ) {
    _handleIncomingBytes(fromPeerId, bytes);
  }

  // -------------------------------------------------------------------------
  // Central
  // -------------------------------------------------------------------------

  Future<void> _startCentralScan() async {
    await _scanSub?.cancel();

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final result in results) {
        final peerId = result.device.remoteId.toString();

        debugPrint(
          '[bitmesh] scan result: '
          'id=$peerId rssi=${result.rssi}',
        );

        _registerDiscoveredPeer(result.device, peerId);
      }
    });

    debugPrint(
      '[bitmesh] starting central scan, '
      'filtering service=${MeshUuids.serviceUuid}',
    );

    await FlutterBluePlus.startScan(
      withServices: [Guid(MeshUuids.serviceUuid)],
      continuousUpdates: true,
    );
  }

  Future<void> _registerDiscoveredPeer(
    BluetoothDevice device,
    String shortId,
  ) async {
    if (!_isRunning) return;

    if (_connectingPeers.contains(shortId)) return;

    final existing = _peers[shortId];

    if (existing != null &&
        existing.linkState == PeerLinkState.connected) {
      return;
    }

    _connectingPeers.add(shortId);

    final tempPeer = existing ??
        Peer(
          peerId: shortId,
          linkState: PeerLinkState.discovered,
        );

    _peers[shortId] = tempPeer;
    notifyListeners();

    try {
      tempPeer.linkState = PeerLinkState.connecting;
      notifyListeners();

      if (device.isConnected != true) {
        await device.connect(timeout: const Duration(seconds: 10));
      }

      var mtu = 23;

      try {
        mtu = await device.requestMtu(247);
        debugPrint('[bitmesh] negotiated MTU with $shortId: $mtu');
      } catch (e) {
        debugPrint(
          '[bitmesh] MTU negotiation unavailable/failed '
          'for $shortId: $e',
        );
      }

      _peerMtu[shortId] = mtu.clamp(23, 517);

      final services = await device.discoverServices();
      final meshService = services.firstWhere(
        (service) =>
            service.uuid.toString().toLowerCase() ==
            MeshUuids.serviceUuid,
      );

      final inbox = meshService.characteristics.firstWhere(
        (characteristic) =>
            characteristic.uuid.toString().toLowerCase() ==
            MeshUuids.inboxCharacteristicUuid,
      );

      _connectedDevices[shortId] = device;
      _outboxCharacteristics[shortId] = inbox;

      await _sendHandshake(shortId);

      tempPeer.linkState = PeerLinkState.connected;
      notifyListeners();

      device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnect(shortId, device, tempPeer);
        }
      });
    } catch (e, st) {
      debugPrint('[bitmesh] connect/discover FAILED for $shortId: $e');
      debugPrint('$st');

      tempPeer.linkState = PeerLinkState.disconnected;
      notifyListeners();
    } finally {
      _connectingPeers.remove(shortId);
    }
  }

  void _handleDisconnect(
    String peerId,
    BluetoothDevice device,
    Peer peer,
  ) {
    _connectedDevices.remove(peerId);
    _outboxCharacteristics.remove(peerId);
    _peerMtu.remove(peerId);
    _writeQueues.remove(peerId);
    _reassembler.clear();

    encryption.dropSession(peerId);

    peer.linkState = PeerLinkState.disconnected;
    notifyListeners();

    if (!_isRunning) return;

    final now = DateTime.now();
    final last = _lastReconnectAttempt[peerId];

    if (last != null &&
        now.difference(last) < const Duration(seconds: 3)) {
      return;
    }

    _lastReconnectAttempt[peerId] = now;

    Future<void>.delayed(const Duration(seconds: 2), () async {
      if (!_isRunning) return;

      final current = _peers[peerId];
      if (current?.linkState != PeerLinkState.disconnected) return;

      debugPrint('[bitmesh] attempting reconnect to $peerId');
      await _registerDiscoveredPeer(device, peerId);
    });
  }

  // -------------------------------------------------------------------------
  // Phase 2 protocol helpers
  // -------------------------------------------------------------------------

  Future<void> _sendHandshake(String peerId) async {
    final ourPublicKey = await encryption.ourPublicKeyBytes();

    final packet = MeshProtocolPacket(
      type: MeshPacketType.noiseHandshake,
      ttl: 1,
      timestampMs: DateTime.now().millisecondsSinceEpoch,
      messageId: const Uuid().v4(),
      senderId: selfPeerId,
      payload: ourPublicKey,
      flags: 0,
    );

    await _writeRaw(peerId, MeshPacketCodec.encode(packet));
  }

  MeshProtocolPacket _buildEncryptedPacket({
    required MeshPacketType type,
    required int ttl,
    required int timestampMs,
    required String msgId,
    required String senderId,
    required Uint8List cipherText,
  }) {
    return MeshProtocolPacket(
      type: type,
      ttl: ttl,
      timestampMs: timestampMs,
      messageId: msgId,
      senderId: senderId,
      payload: cipherText,
      flags: ProtocolConstants.flagEncrypted |
          ProtocolConstants.flagRelayAllowed,
    );
  }

  // -------------------------------------------------------------------------
  // Reliable BLE writes
  // -------------------------------------------------------------------------

  Future<void> _writeRaw(String peerId, Uint8List bytes) {
    final previous = _writeQueues[peerId] ?? Future<void>.value();

    final next = previous
        .catchError((_) {})
        .then<void>((_) => _performWrite(peerId, bytes));

    _writeQueues[peerId] = next;
    return next;
  }

  Future<void> _performWrite(
    String peerId,
    Uint8List bytes,
  ) async {
    final characteristic = _outboxCharacteristics[peerId];

    if (characteristic == null) {
      throw StateError('No BLE characteristic for peer $peerId');
    }

    final mtu = _peerMtu[peerId] ?? 23;
    final maxGattPayload = (mtu - 3).clamp(20, 244);
    final fragmentPayloadSize =
        maxGattPayload - BleFragment.headerSize;

    if (fragmentPayloadSize <= 0) {
      throw StateError('MTU $mtu is too small for BLE fragmentation');
    }

    final total = (bytes.length / fragmentPayloadSize).ceil();

    if (total <= 0 || total > 0xFFFF) {
      throw StateError(
        'Packet is too large for BLE fragmentation: '
        '${bytes.length} bytes',
      );
    }

    final transferId = _uuidToBytes(const Uuid().v4());

    debugPrint(
      '[bitmesh] sending ${bytes.length} bytes to $peerId '
      'as $total BLE fragments '
      '(MTU=$mtu, fragmentPayload=$fragmentPayloadSize)',
    );

    for (var index = 0; index < total; index++) {
      final start = index * fragmentPayloadSize;
      final end = (start + fragmentPayloadSize).clamp(0, bytes.length);

      final fragment = BleFragment(
        transferId: transferId,
        index: index,
        total: total,
        data: Uint8List.fromList(bytes.sublist(start, end)),
      );

      await characteristic.write(
        fragment.encode(),
        withoutResponse: false,
      );
    }
  }

  Uint8List _uuidToBytes(String uuid) {
    final hex = uuid.replaceAll('-', '');
    final bytes = Uint8List(16);

    for (var i = 0; i < 16; i++) {
      bytes[i] = int.parse(
        hex.substring(i * 2, i * 2 + 2),
        radix: 16,
      );
    }

    return bytes;
  }

  // -------------------------------------------------------------------------
  // Sending chat
  // -------------------------------------------------------------------------

  Future<void> sendMessage(String text) async {
    final msgId = const Uuid().v4();
    final timestampMs = DateTime.now().millisecondsSinceEpoch;

    final payload = ChatPayload(
      senderName: selfDisplayName,
      text: text,
      timestampMs: timestampMs,
    );

    final plaintext = payload.encode();
    _markSeen(msgId);

    final message = ChatMessage(
      id: msgId,
      senderId: selfPeerId,
      senderName: selfDisplayName,
      text: text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      isMine: true,
    );

    _messages.add(message);
    await persistence.saveMessage(message);
    notifyListeners();

    await _broadcastPlaintext(
      type: MeshPacketType.message,
      ttl: defaultTtl,
      timestampMs: timestampMs,
      msgId: msgId,
      senderId: selfPeerId,
      plaintext: plaintext,
    );
  }

  Future<void> _broadcastPlaintext({
    required MeshPacketType type,
    required int ttl,
    required int timestampMs,
    required String msgId,
    required String senderId,
    required Uint8List plaintext,
    String? excludePeerId,
  }) async {
    final peerIds = List<String>.from(_connectedDevices.keys);

    for (final peerId in peerIds) {
      if (peerId == excludePeerId) continue;
      if (!encryption.hasSession(peerId)) continue;

      try {
        final cipherText = await encryption.encryptFor(
          peerId,
          plaintext,
        );

        final packet = _buildEncryptedPacket(
          type: type,
          ttl: ttl,
          timestampMs: timestampMs,
          msgId: msgId,
          senderId: senderId,
          cipherText: cipherText,
        );

        await _writeRaw(peerId, MeshPacketCodec.encode(packet));
      } catch (e) {
        debugPrint('[bitmesh] send to $peerId failed: $e');
      }
    }
  }

  // -------------------------------------------------------------------------
  // Receiving + relay
  // -------------------------------------------------------------------------

  Future<void> _handleIncomingBytes(
    String fromPeerId,
    Uint8List bytes,
  ) async {
    final completePacket = _reassembler.add(fromPeerId, bytes);
    if (completePacket == null) return;

    final packet = MeshPacketCodec.decode(completePacket);

    if (packet == null) {
      debugPrint(
        '[bitmesh] malformed protocol packet from $fromPeerId',
      );
      return;
    }

    if (packet.type == MeshPacketType.noiseHandshake) {
      try {
        await encryption.establishSession(
          fromPeerId,
          packet.payload,
        );
      } catch (e) {
        debugPrint(
          '[bitmesh] handshake failed with $fromPeerId: $e',
        );
      }
      return;
    }

    if (packet.type != MeshPacketType.message) {
      debugPrint(
        '[bitmesh] received unsupported protocol type '
        '${packet.type.name} from $fromPeerId',
      );
      return;
    }

    if (!packet.isEncrypted) {
      debugPrint(
        '[bitmesh] dropped unencrypted message ${packet.messageId}',
      );
      return;
    }

    // Only mark the message as seen after authentication/decryption succeeds.
    if (_seenMessageIds.contains(packet.messageId)) return;

    final plaintext = await encryption.decryptFrom(
      fromPeerId,
      packet.payload,
    );

    if (plaintext == null) {
      debugPrint(
        '[bitmesh] dropped undecryptable packet '
        '${packet.messageId} from $fromPeerId',
      );
      return;
    }

    _markSeen(packet.messageId);

    if (packet.senderId != selfPeerId) {
      try {
        final chatPayload = ChatPayload.decode(plaintext);

        final message = ChatMessage(
          id: packet.messageId,
          senderId: packet.senderId,
          senderName: chatPayload.senderName,
          text: chatPayload.text,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            chatPayload.timestampMs,
          ),
          isMine: false,
        );

        _messages.add(message);
        await persistence.saveMessage(message);
        notifyListeners();
      } catch (e) {
        debugPrint(
          '[bitmesh] invalid chat payload '
          '${packet.messageId}: $e',
        );
        return;
      }
    }

    if (packet.ttl > 1 && packet.relayAllowed) {
      final relayedPacket = packet.decrementedForRelay();
      if (relayedPacket == null) return;

      final relayPlaintext = plaintext;

      await _broadcastPlaintext(
        type: relayedPacket.type,
        ttl: relayedPacket.ttl,
        timestampMs: relayedPacket.timestampMs,
        msgId: relayedPacket.messageId,
        senderId: relayedPacket.senderId,
        plaintext: relayPlaintext,
        excludePeerId: fromPeerId,
      );
    }
  }

  void _markSeen(String msgId) {
    if (_seenMessageIds.contains(msgId)) return;

    _seenMessageIds.add(msgId);
    _seenMessageOrder.add(msgId);
    _trimSeenCache();
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
