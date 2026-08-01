# Clean Fresh Laundry — Laundry Management System (LMS)

Tahap 1: **Setup Project & Arsitektur Inti**. Fondasi Clean Architecture,
autentikasi JWT (mock), role-based routing, dan tema Material 3 sudah
berjalan penuh. Modul bisnis (Transaksi, Pelanggan, Layanan, dll)
menyusul di tahap berikutnya di atas fondasi ini.

## ✅ Yang sudah jadi di tahap ini

- **Clean Architecture** per fitur: `data / domain / presentation`
- **State management**: Riverpod (Provider + AsyncNotifier)
- **Routing**: go_router dengan redirect otomatis berbasis session & role
- **Auth**: Login, Logout, Remember Login, Auto Login, Splash Screen,
  Session Management — saat ini memakai **mock API** (belum ada backend)
- **3 Role**: Super Owner, Owner, Kasir — hak akses diatur di
  `lib/shared/enums/user_role.dart` dan otomatis mempengaruhi menu di drawer
- **Tema**: Material Design 3, warna hijau `#2E7D32`/`#66BB6A`, rounded
  corner, soft shadow, sesuai spesifikasi
- **Dashboard** placeholder per role dengan kartu statistik (dummy data)

## 🔑 Akun dummy untuk testing (mock API)

| Username     | Password    | Role        |
|--------------|-------------|-------------|
| `superowner` | `super123`  | Super Owner |
| `owner`      | `owner123`  | Owner       |
| `kasir`      | `kasir123`  | Kasir       |

Mock ada di `lib/features/auth/data/datasources/auth_remote_datasource.dart`
(`AuthRemoteDataSourceMock`). Saat backend Laravel siap, cukup ubah
`AppConstants.useMockApi = false` di `lib/core/constants/app_constants.dart`
dan set `baseUrl` — tidak ada kode lain yang perlu diubah karena repository
sudah bicara lewat interface `AuthRemoteDataSource`.

## 📁 Struktur folder

```
lib/
├── core/                   # Hal lintas fitur: config, network, error, router, utils
│   ├── config/theme/       # AppColors, AppTextStyles, AppTheme (M3)
│   ├── constants/          # AppConstants, StorageKeys
│   ├── error/              # Exceptions (data layer) & Failures (domain layer)
│   ├── network/            # DioClient (interceptor JWT), ApiEndpoints
│   ├── router/             # GoRouter + redirect logic
│   └── utils/              # Result<T> (pengganti Either), Validators
├── shared/
│   ├── enums/               # UserRole + hak akses per role
│   └── widgets/              # AppButton, AppTextField (reusable di semua fitur)
├── features/
│   ├── auth/
│   │   ├── data/            # Model (Freezed), datasource (remote+local), repository impl
│   │   ├── domain/          # Entity, repository interface, use case
│   │   └── presentation/    # Provider (Riverpod), Splash & Login screen
│   └── dashboard/
│       └── presentation/    # Dashboard shell (drawer role-based) + 3 dashboard screen
└── main.dart
```

Pola ini yang dipakai berulang untuk setiap modul baru (Transaksi,
Pelanggan, Layanan, dst.) — silakan contoh fitur `auth` sebagai template.

## 🚀 Cara menjalankan

Project ini dibuat manual (tanpa `flutter create`) karena SDK Flutter
tidak tersedia di lingkungan pembuatan file. Sebelum dijalankan:

```bash
# 1. Buat scaffolding native (android/, ios/, dsb) di folder project ini.
#    Perintah ini AMAN, tidak akan menimpa folder lib/ yang sudah ada.
flutter create .

# 2. Install dependency
flutter pub get

# 3. Generate file Freezed & JSON serialization (WAJIB, karena
#    user_model.dart, dsb menggunakan @freezed / @JsonSerializable)
dart run build_runner build --delete-conflicting-outputs

# 4. Jalankan aplikasi
flutter run
```

Alur: **Splash Screen** (cek auto-login ±1 detik) → jika belum login ke
**Login Screen** → setelah sukses otomatis diarahkan ke **Dashboard**
sesuai role.

## 🗺️ Roadmap tahap berikutnya

Urutan yang disarankan (masing-masing mengikuti pola Clean Architecture
yang sama seperti `auth`):

1. **Master Data**: Pelanggan & Layanan Laundry (CRUD + mock API)
2. **Transaksi (POS)**: form transaksi, kalkulasi otomatis, invoice generator
3. **QR Code**: generate QR invoice + scan QR untuk buka detail transaksi
4. **Status Laundry**: state machine Diterima → ... → Sudah Diambil
5. **Bluetooth Thermal Printer**: cetak bon 58mm sesuai format yang ditentukan
6. **Riwayat Transaksi & Laporan**: filter, export PDF/Excel
7. **Manajemen User**: khusus Owner/Super Owner
8. **Pengaturan**: profil laundry, printer default, backup/restore
9. **Backend Laravel**: REST API + MySQL menggantikan mock (kontrak
   endpoint sudah didefinisikan di `lib/core/network/api_endpoints.dart`)

lanjutan udah selesai sudah menyelesaikan 5 tahap implementasi lokal/mock.

1. Fondasi aplikasi Clean Architecture, Riverpod, GoRouter, Material 3 hijau. Auth mock: Splash, Login, Logout, JWT mock, Remember Login. Tiga role: Super Owner, Owner, Kasir; dashboard dan menu menyesuaikan akses.

2. Master data Pelanggan: lihat, tambah, edit. Layanan laundry: lihat, tambah, edit, harga, estimasi, per Kg/per Item.

3. POS & transaksi Transaksi baru: pelanggan, layanan, berat/jumlah, Express, catatan. Hitung subtotal, biaya Express, total. Metode pembayaran Tunai/QRIS/Transfer serta status Belum Bayar/DP/Lunas. Detail dan update status laundry.

4. Riwayat & QR Daftar transaksi sebagai riwayat. QR invoice sebagai kode pengambilan. Scan QR dengan kamera untuk membuka transaksi.

5. Administrasi & cetak bon Laporan ringkas pendapatan/operasional dari transaksi. Manajemen akun Owner/Kasir berbasis role. Pengaturan profil laundry, ukuran kertas, dan MAC printer default. Cetak bon ESC/POS 58 mm melalui Bluetooth.



TERBARU 02/02/2026
feat: Integrasi Penuh API Transaksi, Master Data, dan Logika Status Otomatis

Pembaruan ini mencakup penyelesaian integrasi aplikasi mobile (Flutter) dengan backend (Laravel), perbaikan UI/UX pada modul transaksi, serta pembersihan kode. Aplikasi sekarang sudah berjalan lancar dan aman dengan data dari server lokal.

### 🔗 Integrasi Backend & Auth
* Mengatur ulang IP backend ke `192.168.1.12` dan memastikan koneksi Flutter ↔ Laravel berjalan dengan baik[cite: 3, 4].
* Memperbaiki sistem autentikasi dan session; token Bearer kini lebih stabil dan tidak cepat hilang meskipun fitur "remember me" dimatikan[cite: 3].

### 👥 Master Data (Pelanggan & Layanan)
* Menghubungkan fitur pelanggan sepenuhnya ke backend untuk proses Read dan Create[cite: 3].
* Menambahkan kemampuan untuk membuka detail pelanggan langsung dari daftar pelanggan[cite: 3].
* Memperbarui entitas dan model Layanan untuk mendukung *field* satuan estimasi menggunakan *enum*, yang dapat dipilih langsung oleh *owner* di UI[cite: 4].

### 🛒 Modul Transaksi & Logika Bisnis
* Memperbaiki *payload* transaksi agar kompatibel dengan validasi Laravel (mengirim `customer_id`, `payment_status`, dan `services` sebagai array yang memuat `service_id`, `qty`, dan `price`)[cite: 3].
* Menyesuaikan *parser* transaksi agar respons dari backend langsung memuat relasi data pelanggan dan layanan[cite: 4].
* Menambahkan logika status otomatis pada transaksi berbasis waktu estimasi (sebelum estimasi selesai = diproses, saat estimasi selesai = selesai, lewat batas = telat)[cite: 4].
* Menambahkan opsi untuk menambah pelanggan baru secara langsung dari form pembuatan transaksi[cite: 3].
* Memperbarui *provider* agar otomatis melakukan *refresh* daftar transaksi setelah transaksi baru berhasil dibuat[cite: 4].

### 🎨 UI/UX & Fitur Filter
* Menambahkan fungsionalitas UI untuk mengubah status menjadi "Lunas & Sudah Diambil" di halaman detail transaksi[cite: 4].
* Menerapkan filter pencarian/kategori di halaman riwayat transaksi yang sinkron dengan status otomatis[cite: 4].
* Memperbaiki *bug* navigasi saat kembali dari halaman tambah layanan di perangkat Android[cite: 4].

### 🛠️ Pengujian & Pembersihan Kode (Chore)
* Membersihkan *syntax*, menghapus *import* yang tidak terpakai, dan mengganti properti Flutter yang *deprecated*[cite: 4].
* Lolos pengecekan `dart analyze` tanpa ada *error logic* maupun *style*[cite: 4].
* Menambahkan dan memastikan uji regresi (*test*) untuk *payload* dan domain transaksi tetap lolos/valid[cite: 3, 4].

**Catatan untuk Tim:**
Secara umum *flow* transaksi dan pelanggan sudah terhubung dengan aman ke API[cite: 3]. Modul transaksi sekarang sudah cerdas dalam menghitung waktu estimasi dan merubah status secara otomatis.