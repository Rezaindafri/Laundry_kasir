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

feat: Integrasi Penuh API Transaksi, Master Data, dan Logika Status Otomatis

Pembaruan skala besar ini mencakup penyelesaian integrasi aplikasi Flutter dengan backend Laravel, perbaikan UI/UX, serta penyempurnaan alur transaksi. Aplikasi sekarang sudah berjalan stabil menggunakan data dari server lokal.

### 🔗 Integrasi Backend, Auth & Konfigurasi
* Mengatur endpoint API ke backend Laravel dan mengaktifkan izin internet serta cleartext traffic di Android.
* Mengubah IP backend Flutter menjadi `192.168.1.12`.
* Memperbaiki behavior penyimpanan token di secure storage; sesi kini tetap berlaku selama user aktif meski fitur "remember me" dimatikan, mencegah request API gagal (401)[cite: 3].
* Bug logic kecil di repository transaksi berhasil dibetulkan.

### 👥 Master Data Pelanggan
* Mengubah sumber data pelanggan dari mock/dummy menjadi data langsung dari API backend[cite: 3].
* Menyesuaikan parsing data pelanggan dari format response API[cite: 3].
* Menambahkan alur buka detail pelanggan langsung dari daftar pelanggan dan memperjelas tombol edit pelanggan[cite: 3].
* Menambahkan opsi "Tambah pelanggan baru" langsung dari form pembuatan transaksi[cite: 3].

### 📦 Master Data Layanan
* Model layanan kini mendukung field satuan estimasi dengan enum[cite: 4].
* UI owner sekarang bisa memilih satuan saat membuat atau menyunting layanan[cite: 4].
* Memperbaiki error navigasi kembali (back navigation) saat membuka halaman tambah layanan di Android[cite: 4].

### 🛒 Modul Transaksi & Payload
* Memperbaiki payload transaksi agar kompatibel dengan validasi Laravel, memastikan pengiriman `customer_id`, `payment_status`, dan `services` sebagai array yang memuat harga per item (`price`) dan kuantitas (`qty`)[cite: 3].
* Menyesuaikan parser transaksi Flutter supaya response create/update ikut memuat relasi data `customer` dan `transactionDetails.service` dari backend[cite: 4].
* Provider transaksi kini otomatis me-refresh ulang daftar dari backend setelah transaksi berhasil dibuat[cite: 4].
* Menampilkan estimasi layanan pada UI transaksi dan juga pada bon/struk[cite: 4].
* Memastikan field `estimation_hours` dan `estimation_unit` tetap kompatibel dengan payload backend[cite: 4].

### 🔄 Logika Status Otomatis & UI
* Status transaksi sekarang berkembang otomatis berdasarkan estimasi layanan yang dikonversi ke jam: diproses (sebelum estimasi selesai), selesai (saat estimasi selesai), dan telat (melewati batas)[cite: 4].
* Menambahkan tombol "Lunas & Sudah Diambil" dengan logika cerdas: 
  - Jika sudah lunas, tombol cukup menandai barang sudah diambil[cite: 4].
  - Jika belum lunas, tombol menandai proses pengambilan namun tetap mempertahankan status pembayaran sebelumnya[cite: 4].
* Sinkronisasi filter pencarian dan chip status di layar riwayat transaksi agar memakai status yang dihitung otomatis[cite: 4].

### 🛠️ Pengujian & Validasi
* Lolos pengecekan `dart analyze` tanpa ada error logic/style untuk file-file transaksi[cite: 4].
* Mengganti properti Flutter yang deprecated dan merapikan syntax[cite: 4].
* Lolos validasi `php -l` untuk controller Laravel tanpa syntax error[cite: 4].
* Menambahkan uji regresi (test) untuk memastikan payload transaksi tetap sesuai struktur backend; semua pengujian domain entitas lolos.


### Yang kau coba ganti
Jadi nanti itu kau perlu setup ulang lagi, karena kan ini perlu backend. semisal kau gak mau pasang backend, kau bisa pakai dulu dummynya. Caranya:
* masuk ke 'transaction_providers.dart'
* Ubah status 'useMockApi' dari 'const bool useMockApi = false;' menjadi 'const bool useMockApi = true;'

nah ntar tinggal jalani kek biasa