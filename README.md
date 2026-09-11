# MeshTalk 📡

**A Decentralized Bluetooth Mesh Chat Application**

MeshTalk lets nearby devices exchange messages over Bluetooth Low Energy (BLE) — no internet, SIM card, or central server required. Messages relay across multiple hops through intermediate peers, reaching devices beyond direct BLE range, with full end-to-end encryption.

## 🚀 Features
- **Offline-first**: Works entirely without internet or cellular data
- **Multi-hop mesh relay**: TTL-based routing with duplicate suppression
- **End-to-end encryption**: X25519 key exchange + AES-GCM
- **Account-free**: Ephemeral, anonymous peer identities
- **Cross-platform**: Built with Flutter (Android/iOS)
- **Local persistence**: Chat history stored via Hive/SQLite

## 🏗️ Architecture
Layered design: **Application/UI → Mesh Routing → Security → BLE Communication**

## 🛠️ Tech Stack
- **Language**: Dart (Flutter)
- **BLE**: flutter_reactive_ble
- **Encryption**: cryptography package (X25519, AES-GCM)
- **Storage**: Hive / SQLite
- **Version Control**: Git / GitHub

## 👥 Team — Techtrio
| Member | Role |
|---|---|
| Aditya Kumar | Team Lead — Architecture & Mesh Routing |
| Ashish Sharma | BLE Communication Layer |
| Piyush Kumar | Security Layer |
| Sarthak Verma | UI & Local Persistence |

**Mentor**: Mr. Prajjwal Kumar

## 📌 Project Status
Currently in **Phase-I: Proposal & Design** as part of the PBL curriculum at Graphic Era (Deemed to be University), Dehradun.

## 📄 References
- [Bluetooth SIG – BLE Core Specifications](https://www.bluetooth.com/specifications/specs/)
- [Flutter Documentation](https://docs.flutter.dev/)
- [BitChat by Jack Dorsey](https://github.com/jackjackbits/bitchat)
- [cryptography package](https://pub.dev/packages/cryptography)
