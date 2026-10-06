# MeshTalk Phase 1 — Reliable BLE Transport

Replace these files in your project:

- `lib/services/ble_mesh_service.dart`
- `lib/services/ble_fragment.dart`
- `lib/services/ble_reassembler.dart`

This phase adds:

- BLE MTU negotiation
- Explicit fragmentation headers
- Receiver-side reassembly
- Per-peer serialized BLE write queues
- Reconnect-safe peer discovery
- Automatic reconnect attempts
- Safer deduplication after successful decryption
- Basic malformed payload handling

Then run:

```powershell
cd C:\dev\bitmesh_chat

flutter analyze
flutter test

git add .
git commit -m "Fix BLE transport reliability"
git push
```

Test with two phones first:

1. Connect A ↔ B.
2. Send a short message.
3. Send a 500–1000 character message.
4. Disconnect B and bring it back into range.
5. Send several messages rapidly.
6. Then test A → B → C relay.
