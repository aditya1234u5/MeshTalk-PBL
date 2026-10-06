MeshTalk — Phase 2: Protocol Layer

This phase adds a dedicated application-layer binary protocol under:
  lib/protocol/

Files:
  protocol_constants.dart
  packet_type.dart
  packet.dart
  packet_codec.dart
  protocol_fragment.dart

A unit-test suite is also included:
  test/protocol/packet_codec_test.dart

IMPORTANT:
- Do NOT delete lib/models/mesh_packet.dart yet.
- Phase 1 BLE fragmentation in lib/services/ble_fragment.dart remains separate.
- These Phase 2 classes are not yet wired into BleMeshService.
- This is an incremental protocol layer, not a claim of full BitChat wire compatibility.
- Phase 3 will address persistent cryptographic peer identity.
- Phase 4 will address Noise XX.

Verification:
  flutter analyze
  flutter test

If both pass:
  git add .
  git commit -m "Add application protocol layer"
  git push
