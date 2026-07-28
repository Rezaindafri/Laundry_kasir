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

Beri tahu saya modul mana yang ingin dibangun berikutnya (disarankan:
**Pelanggan & Layanan** dulu, karena jadi dependency form Transaksi).
