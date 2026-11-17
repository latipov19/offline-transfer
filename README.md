# 📡 Offline Transfer

> **No internet. No cloud. No server.** — Peer-to-peer fayl uzatish ilovasi.

Offline Transfer — Wi-Fi Direct va Bluetooth orqali qurilmalar o'rtasida fayllarni internetga ulanmasdan yuborish va qabul qilish uchun mo'ljallangan Flutter ilovasi.

---

## ✨ Xususiyatlar

- 🔗 **Peer-to-Peer ulanish** — Wi-Fi Direct / Nearby Connections orqali
- 📷 **QR kod bilan juftlash** — Tez va oson ulanish
- 🔐 **AES-256-GCM shifrlash** — Xavfsiz fayl uzatish
- ✅ **SHA-256 tekshiruv** — Fayl yaxlitligini kafolatlaydi
- 📂 **Barcha fayl turlari** — Rasm, video, hujjat, arxiv va boshqalar
- 📜 **Tarix** — O'tkazilgan fayllar tarixi (Hive DB)
- 🌙 **Dark / Light tema** — Avtomatik va qo'lda sozlash
- ⏸️ **Resume qo'llab-quvvatlash** — Uzilgan uzatishni davom ettirish

---

## 🛠️ Texnologiyalar

| Texnologiya | Maqsad |
|-------------|--------|
| **Flutter 3.x** | Cross-platform UI framework |
| `nearby_connections` | Wi-Fi Direct / Bluetooth P2P |
| `qr_flutter` + `mobile_scanner` | QR kod yaratish va skanerlash |
| `hive` + `hive_flutter` | Local ma'lumotlar bazasi |
| `encrypt` (AES-256-GCM) | Fayl shifrlash |
| `crypto` (SHA-256) | Fayl xesh tekshiruvi |
| `file_picker` | Fayl tanlash |
| `permission_handler` | Ruxsatlarni boshqarish |

---

## 📱 Platformalar

| Platform | Holati |
|----------|--------|
| Android | ✅ Qo'llab-quvvatlanadi |
| iOS | 🔄 Ishlanmoqda |
| Web | ⚠️ Cheklangan (Nearby API yo'q) |

---

## 🚀 Ishga tushirish

### Talablar
- Flutter SDK `^3.13.4`
- Dart SDK `^3.13.4`
- Android Studio yoki VS Code

### O'rnatish

```bash
# Reponi clone qiling
git clone https://github.com/latipov19/offline-transfer.git
cd offline-transfer

# Bog'liqliklarni o'rnating
flutter pub get

# Hive kodlarini yarating
dart run build_runner build

# Ilovani ishga tushiring
flutter run
```

---

## 📁 Loyiha tuzilmasi

```
lib/
├── core/
│   ├── constants/     # App konstantalari
│   ├── errors/        # Xatoliklar
│   ├── permissions/   # Ruxsatlar
│   └── utils/         # Yordamchi funksiyalar
├── models/            # Ma'lumot modellari (Hive)
├── repositories/      # Ma'lumotlar ombori
├── screens/           # UI ekranlar
│   ├── home_screen.dart
│   ├── send_screen.dart
│   ├── receive_screen.dart
│   ├── transfer_screen.dart
│   ├── history_screen.dart
│   └── settings_screen.dart
├── services/          # Biznes logika
│   ├── nearby_service.dart
│   ├── transfer_service.dart
│   ├── encryption_service.dart
│   └── storage_service.dart
├── theme/             # Tema sozlamalari
├── widgets/           # Umumiy widget'lar
└── main.dart
```

---

## 🔐 Xavfsizlik

- Barcha fayllar **AES-256-GCM** bilan shifrlanadi
- Har bir uzatish uchun **SHA-256** xesh tekshiruvi amalga oshiriladi
- Internet ulanishi **talab qilinmaydi** — ma'lumotlar bulutga chiqmaydi

---

## 👨‍💻 Muallif

**Latipov** — [@latipov19](https://github.com/latipov19)

---

## 📄 Litsenziya

Bu loyiha [MIT License](LICENSE) ostida tarqatiladi.
