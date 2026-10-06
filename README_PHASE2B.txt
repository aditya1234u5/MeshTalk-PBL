MeshTalk — Phase 2B: Integrate Protocol Layer

Replace:
  lib/services/ble_mesh_service.dart

Add:
  test/protocol/phase2b_protocol_integration_test.dart

The replacement service keeps Phase 1 BLE transport behavior and changes the
application packet boundary to:

  MeshProtocolPacket -> MeshPacketCodec -> BLE fragmentation
  BLE reassembly -> MeshPacketCodec -> MeshProtocolPacket

Do NOT replace lib/protocol. Keep the Phase 2 protocol files already installed.

After copying, run:
  flutter analyze
  flutter test

Do not push until both commands have been checked.
