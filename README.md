# 📡 Offline Transfer

> **No internet. No cloud. No server.** — Peer-to-peer file transfer app built with Flutter.

Offline Transfer lets you send and receive files between devices over Wi-Fi Direct and Bluetooth — completely offline, with no servers or cloud storage involved.

---

## ✨ Features

- 🔗 **Peer-to-Peer Connection** — Wi-Fi Direct via Nearby Connections API
- 📷 **QR Code Pairing** — Fast and easy device discovery
- 🔐 **AES-256-GCM Encryption** — Every file is encrypted in transit
- ✅ **SHA-256 Integrity Check** — Verify files are transferred without corruption
- 📂 **All File Types** — Images, videos, documents, archives, and more
- 📜 **Transfer History** — Persistent history stored locally with Hive
- 🌙 **Dark / Light Theme** — Manual and system-aware theming
- ⏸️ **Resume Support** — Continue interrupted transfers

---

## 🛠️ Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter 3.x** | Cross-platform UI framework |
| `nearby_connections` | Wi-Fi Direct / Bluetooth P2P |
| `qr_flutter` + `mobile_scanner` | QR code generation & scanning |
| `hive` + `hive_flutter` | Local database for history & settings |
| `encrypt` (AES-256-GCM) | File encryption |
| `crypto` (SHA-256) | File integrity verification |
| `file_picker` | File selection |
| `permission_handler` | Runtime permissions management |

---

## 📱 Platform Support

| Platform | Status |
|----------|--------|
| Android | ✅ Supported |
| iOS | 🔄 In progress |
| Web | ⚠️ Limited (Nearby API unavailable) |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK `^3.13.4`
- Dart SDK `^3.13.4`
- Android Studio or VS Code

### Installation

```bash
# Clone the repository
git clone https://github.com/latipov19/offline-transfer.git
cd offline-transfer

# Install dependencies
flutter pub get

# Generate Hive adapters
dart run build_runner build

# Run the app
flutter run
```

---

## 📁 Project Structure

```
lib/
├── core/
│   ├── constants/     # App-wide constants
│   ├── errors/        # Custom exceptions
│   ├── permissions/   # Permission handling
│   └── utils/         # Utility functions
├── models/            # Data models (Hive adapters)
├── repositories/      # Data access layer
├── screens/           # UI screens
│   ├── home_screen.dart
│   ├── send_screen.dart
│   ├── receive_screen.dart
│   ├── transfer_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
├── services/          # Business logic
│   ├── nearby_service.dart
│   ├── transfer_service.dart
│   ├── encryption_service.dart
│   └── storage_service.dart
├── theme/             # App theming
├── widgets/           # Reusable widgets
└── main.dart
```

---

## 🔐 Security

- All files are encrypted using **AES-256-GCM** before transfer
- **SHA-256** checksum validation on every received file
- No internet connection required — your data never leaves your local network

---

## 👨‍💻 Author

**Latipov** — [@latipov19](https://github.com/latipov19)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
