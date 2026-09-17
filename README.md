# \# bitmesh\_chat

# 

# A BitChat-inspired decentralized BLE mesh chat app, built in Flutter.

# Every phone runs BOTH a BLE peripheral (advertises + accepts writes) and a

# BLE central (scans + connects + writes) role at once, so messages can hop

# phone-to-phone with no internet, accounts, or servers.

# 

# \## Architecture at a glance

# 

# ```

# lib/

# &#x20; models/

# &#x20;   peer.dart          - a nearby mesh node + its connection state

# &#x20;   message.dart        - a chat message for the UI layer

# &#x20;   mesh\_packet.dart     - the wire protocol (version/type/ttl/ids/payload)

# &#x20; services/

# &#x20;   encryption\_service.dart   - X25519 per-peer session keys + AES-GCM

# &#x20;   persistence\_service.dart - Hive-based local chat history storage

# &#x20;   ble\_mesh\_service.dart     - central+peripheral roles, handshake, relay + dedup

# &#x20;   permissions\_service.dart - runtime BT/location permission requests

# &#x20; screens/

# &#x20;   setup\_screen.dart   - display name entry (no passphrase needed anymore)

# &#x20;   chat\_screen.dart    - message list + input bar + topology toggle

# &#x20; widgets/

# &#x20;   message\_bubble.dart

# &#x20;   mesh\_topology\_view.dart  - draws self + direct (1-hop) neighbors

# ```

# 

# The mesh protocol (`mesh\_packet.dart` + the relay logic in

# `ble\_mesh\_service.dart`) is plain Dart with no BLE dependency, so you can

# unit-test dedup/TTL behavior without any Bluetooth hardware.

# 

# \## Setup

# 

# ```

# flutter pub get

# flutter run

# ```

# 

# You need \*\*2-3 physical phones\*\* with Bluetooth on. BLE mesh cannot be

# meaningfully tested on emulators/simulators - do not lose time trying.

# 

# \## Platform-specific setup you still need to do

# 

# \### Android

# Permissions are already in `android/app/src/main/AndroidManifest.xml`.

# Make sure `minSdkVersion` in `android/app/build.gradle` is at least 21

# (23+ recommended for reliable BLE peripheral mode).

# 

# \### iOS

# Add to `ios/Runner/Info.plist`:

# ```xml

# <key>NSBluetoothAlwaysUsageDescription</key>

# <string>bitmesh uses Bluetooth to find and message nearby peers</string>

# <key>UIBackgroundModes</key>

# <array>

# &#x20; <string>bluetooth-central</string>

# &#x20; <string>bluetooth-peripheral</string>

# </array>

# ```

# Known iOS limitation: CoreBluetooth throttles peripheral advertising in the

# background, and local names may not appear in scan results if the app was

# backgrounded first. Keep the app foregrounded while testing peripheral mode.

# 

# \## Peripheral GATT server wiring (do this before your first test)

# 

# `flutter\_ble\_peripheral`'s API for receiving incoming writes differs a bit

# by version. In `ble\_mesh\_service.dart`, `\_startPeripheral()` sets up

# advertising, but you need to also wire up whatever the installed version

# calls its "on write request" stream/callback, and forward the bytes into

# `onPeripheralDataReceived()`. Check the plugin's example app for the exact

# name (recent versions expose something like a `dataStreamController` you

# subscribe to) - this is the single place plugin API drift is most likely,

# so verify against whatever version `flutter pub get` actually resolves.

# 

# \## MTU \& chunking

# 

# Default BLE MTU is tiny (\~20 bytes). The code chunks writes into \~180-byte

# pieces assuming a negotiated MTU - add an explicit `device.requestMtu(512)`

# call (Android) right after `connect()` in `ble\_mesh\_service.dart` once basic

# sends are working, and re-test chunk size against whatever MTU you actually

# get back, since it varies by device.

# 

# \## Encryption model: hop-by-hop, not end-to-end-to-recipient

# 

# Each device generates a fresh X25519 identity keypair on startup. When it

# connects directly to a neighbor, both sides exchange public keys (a

# `typeHandshake` packet, ttl=1, never relayed) and derive a shared AES-256

# session key via HKDF. Every message is encrypted separately per direct

# neighbor with that neighbor's own session key, and a relaying device

# decrypts an incoming message, then re-encrypts it with a \*different\* key

# before forwarding it to its own neighbors.

# 

# \*\*This is a deliberate trade-off worth stating plainly if asked in your

# evaluation\*\*: because this is a broadcast group chat (everyone in the mesh

# sees every message), true end-to-end encryption to one final recipient

# isn't possible without breaking that broadcast model - a message either

# has one recipient who can decrypt it, or it's meant for everyone, not

# both. Hop-by-hop still means every neighbor-to-neighbor link is encrypted

# and a passive BLE sniffer between two phones learns nothing, but a

# \*relaying device itself\* does see the plaintext momentarily, unlike true

# e2e. A 1:1 private-message feature (where only the final recipient could

# decrypt) is a clean addition to list under Future Scope.

# 

# \## Known rough edge: peer display names

# 

# The handshake packet currently only carries the public key, not the

# peer's chosen display name - so the topology view falls back to showing

# each neighbor's short peer ID instead of their name. Fixing this is

# small: extend the handshake payload to `\[pubkey]\[displayName bytes]` and

# update `\_sendHandshake`/`establishSession` to parse both parts.

# 

# \## Testing the mesh (recommended build order)

# 

# 1\. \*\*2 phones, in range\*\*: confirm direct send/receive works both ways.

# 2\. \*\*2 phones, one message each way\*\*: confirm your own message doesn't

# &#x20;  boomerang back to you (checks the dedup cache in `\_handleIncomingBytes`).

# 3\. \*\*3 phones, A and C out of BLE range of each other but both in range of

# &#x20;  B\*\*: send from A, confirm C receives it via relay through B. This is

# &#x20;  the actual "mesh" proof and the one you want on video for your demo.

# 4\. \*\*Kill B mid-relay\*\*: confirm A and C simply lose the relay path (no

# &#x20;  crash) - good to mention as a known limitation (no store-and-forward yet).

# 

# \## Known limitations / good "Future Scope" material for your synopsis

# 

# \- \*\*Flood-based relay, no routing table\*\*: every message goes to every

# &#x20; connected peer (minus dedup). Fine at demo scale (a handful of phones),

# &#x20; would need real routing (e.g. distance-vector) to scale further.

# \- \*\*No store-and-forward\*\*: if a peer is out of range when a message is

# &#x20; sent, it never receives it later. Real BitChat has partial support for

# &#x20; this; worth a paragraph on how you'd add it (cache + retry on reconnect).

# \- \*\*Hop-by-hop encryption, not e2e-to-final-recipient\*\*: see the dedicated

# &#x20; section above - this is a deliberate trade-off given the broadcast chat

# &#x20; model, and a 1:1 private-message mode is the natural Future Scope item.

# \- \*\*Peer display names not in the handshake yet\*\*: see "Known rough edge"

# &#x20; above - topology view shows peer IDs, not names, until this is added.

# \- \*\*Topology view only draws 1-hop neighbors\*\*: flood relay carries no

# &#x20; path information, so we can't honestly draw the full multi-hop mesh

# &#x20; graph - only what a device directly knows (its own live connections).

# \- \*\*iOS background behavior\*\*: see platform note above.

# 

