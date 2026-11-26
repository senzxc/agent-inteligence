<div align="center">
  <img src="assets/icon/app_icon.png" alt="Agent Intelligence" width="120">
  <h1>Agent Intelligence</h1>
  <p>Aplikasi pemantauan dan pengelolaan aktivitas agen lapangan.</p>

  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white" alt="Node.js">
  <img src="https://img.shields.io/badge/Express-000000?style=for-the-badge&logo=express&logoColor=white" alt="Express">
  <img src="https://img.shields.io/badge/Oracle-F80000?style=for-the-badge&logo=oracle&logoColor=white" alt="Oracle Database">
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase">
  <img src="https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
</div>

---

## ✨ Tentang aplikasi

**Agent Intelligence** membantu agen dan tim memantau aktivitas lapangan dalam satu aplikasi. Agen dapat melihat tugas dan memperbarui profil, sementara informasi lokasi dan status agen dapat dipantau melalui peta.

### Fitur utama

- 📍 **Pelacakan lokasi agen** — pembaruan lokasi berjalan di latar belakang Android dengan notifikasi layanan aktif.
- 🗺️ **Peta dan kantor** — melihat lokasi agen dan daftar kantor pada peta.
- 👥 **Pemantauan tim** — melihat daftar, profil, dan status kehadiran agen.
- ✅ **Manajemen tugas** — melihat tugas agen dan memperbarui status pengerjaan.
- 🔔 **Push notification** — menerima notifikasi Firebase Cloud Messaging di Android.
- 🖼️ **Profil agen** — mengubah informasi dan foto profil.
- 🆕 **Catatan pembaruan** — melihat changelog aplikasi dari dashboard.

## 🧰 Teknologi

| Area | Teknologi |
| --- | --- |
| Aplikasi mobile | Flutter, Dart |
| Peta dan lokasi | `flutter_map`, `geolocator`, `geocoding` |
| Backend API | Node.js, Express |
| Database | Oracle Database |
| Notifikasi Android | Firebase Cloud Messaging, local notifications |
| Penyimpanan tugas | JSON |

## 🚀 Menjalankan aplikasi

### Prasyarat

- Flutter SDK dan Dart SDK yang sesuai dengan batas SDK di [`pubspec.yaml`](pubspec.yaml)
- Android Studio atau perangkat Android untuk menjalankan aplikasi
- Node.js dan akses Oracle Database jika ingin menjalankan backend

### Aplikasi Flutter

```powershell
flutter pub get
flutter run
```

Firebase Android telah dikonfigurasi untuk proyek ini. Untuk menguji aplikasi pada perangkat, pastikan perangkat memiliki izin lokasi dan notifikasi yang diperlukan.

### Backend

Backend membutuhkan koneksi Oracle. Siapkan variabel lingkungan berikut di `backend/.env` sebelum menjalankannya:

```dotenv
PORT=3000
ORACLE_USER=nama_pengguna
ORACLE_PASSWORD=password
ORACLE_CONNECT_STRING=host:port/service_name
```

Jangan commit file `.env` atau membagikan kredensial database.

```powershell
cd backend
npm install
node server.js
```

Jalankan pengujian backend dengan:

```powershell
npm test
```

## 📍 Pelacakan lokasi Android

Pelacakan dimulai otomatis setelah login dan menggunakan foreground location service dengan notifikasi permanen saat aktif. Pembaruan tetap berjalan saat aplikasi berada di latar belakang atau layar terkunci. Agen dinyatakan offline setelah 2 menit tanpa pembaruan lokasi dan kembali online setelah pembaruan diterima. Android tetap dapat menghentikan proses jika aplikasi dihentikan paksa atau perangkat menerapkan pembatasan baterai.

## 🔔 Push notification Android (FCM)

Firebase dan FCM diinisialisasi saat aplikasi Android dibuka. Izin notifikasi diminta oleh Android, notifikasi saat aplikasi terbuka ditampilkan sebagai notifikasi lokal, dan notifikasi FCM dengan payload notification ditampilkan otomatis saat aplikasi berada di latar belakang. Untuk iOS, konfigurasi APNs masih perlu disiapkan terpisah.

Untuk tes manual, kirim pesan uji dari Firebase Console ke token FCM perangkat. Token hanya dicetak bila build dibuat dengan `--dart-define=LOG_FCM_TOKEN=true`; **jangan gunakan opsi ini pada APK yang dibagikan ke publik**:

```powershell
flutter build apk --release --dart-define=LOG_FCM_TOKEN=true
adb logcat -s flutter
```

Salin token dari log lokal ke fitur **Send test message** di Firebase Console. Build publik biasa dibuat tanpa `--dart-define`, sehingga token tidak dicetak. Firebase Console cocok untuk pengujian manual; pengiriman otomatis atau tertarget ke pengguna aplikasi membutuhkan backend tepercaya yang mengirim melalui Firebase Admin SDK atau Cloud Functions. Jangan menyimpan kredensial Admin SDK di aplikasi Flutter.

## 🆕 Changelog aplikasi

Changelog terbaru ditampilkan sekali saat pertama kali aplikasi dibuka atau setelah versi/build aplikasi berubah. Pengguna dapat membukanya kembali dari ikon **Apa yang baru?** di dashboard. Hanya catatan versi terbaru yang disimpan; perbarui `latestEntries` di [`lib/services/changelog_service.dart`](lib/services/changelog_service.dart) untuk rilis berikutnya dan naikkan nomor versi/build di [`pubspec.yaml`](pubspec.yaml).

## 📦 Membuat APK release Android

APK release harus ditandatangani dengan key milik pemilik aplikasi. Buat key sekali dan simpan di luar repository; jangan kirim atau commit file key maupun password-nya:

```powershell
keytool -genkey -v -keystore "$env:USERPROFILE\agent-tracker-upload-key.jks" -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Salin `android/key.properties.example` menjadi `android/key.properties`, lalu isi password dan path absolut ke file `.jks` yang dibuat. File key dan `key.properties` sudah diabaikan Git. Build APK publik tanpa flag diagnostik:

```powershell
flutter build apk --release
```

APK tersedia di `build/app/outputs/flutter-apk/app-release.apk`. Pengguna yang sudah memasang build dengan tanda tangan berbeda (misalnya debug) perlu mencopotnya sebelum memasang APK ini. Pembaruan APK berikutnya harus menggunakan key penandatangan yang sama.

ID paket saat ini adalah `com.example.agent_inteligence` dan cocok dengan konfigurasi Firebase yang ada. ID itu dipertahankan untuk tes APK langsung; sebelum distribusi publik jangka panjang, ganti dengan ID unik milik aplikasi dan daftarkan ID yang sama sebagai aplikasi Android di Firebase.
