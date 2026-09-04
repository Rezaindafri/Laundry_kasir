# Dokumentasi Proyek Laundry Management System

## 1. Gambaran Umum Proyek

Proyek ini adalah aplikasi manajemen laundry berbasis mobile Flutter yang didesain untuk membantu operasional bisnis laundry, mulai dari:

- autentikasi pengguna
- data pelanggan
- data layanan laundry
- pencatatan transaksi
- status laundry
- pembayaran
- laporan dan administrasi
- pencetakan bon/struk
- scan QR transaksi
- pengaturan printer dan profil laundry

Aplikasi ini dibangun dengan pendekatan Clean Architecture di sisi frontend, sedangkan backend menggunakan Laravel dengan autentikasi Sanctum dan API REST.

Project frontend berada di folder:

- `laundry_app/`

Backend Laravel berada pada:

- `D:\laragon\www\api-indafri-laundry`

---

## 2. Status Proyek Saat Ini

Proyek ini sudah berjalan dalam fase integrasi penuh antara frontend Flutter dan backend Laravel. Struktur aplikasi sudah tidak lagi murni mock-only, meskipun masih ada opsi fallback mock untuk kebutuhan development/test.

Beberapa indikator status:

- Autentikasi login dengan JWT-like token via Laravel Sanctum sudah siap.
- Data pelanggan dan layanan sudah bergerak dari mock ke API backend.
- Transaksi sudah terintegrasi ke backend.
- Router dan role-based access sudah dibuat.
- UI untuk transaksi, pelanggan, layanan, laporan, scan QR, dan printer sudah dibangun.
- Backend menyediakan endpoint API dasar CRUD untuk customer, service, dan transaction.

Konfigurasi utama app mobile ada di `lib/core/constants/app_constants.dart`:

- `baseUrl = 'http://192.168.1.12/api-indafri-laundry/public/api'`
- `useMockApi = false`

Artinya, aplikasi sekarang diarahkan ke API server lokal real, bukan dummy.

---

## 3. Stack Teknologi

### Frontend (Flutter)

- Flutter SDK
- Riverpod untuk state management
- GoRouter untuk routing/navigation
- Material 3 untuk design system
- Dio untuk HTTP client
- flutter_secure_storage dan shared_preferences untuk sesi/token
- image_picker untuk mengambil bukti foto pengambilan
- QR code scanner dan generator
- Bluetooth thermal printer support
- Intl untuk format angka/tanggal lokal Indonesia

### Backend (Laravel)

- Laravel
- Sanctum untuk API authentication
- MySQL/SQLite (dalam project local bisa sqlite untuk dev; struktur model siap untuk database mysql)
- Eloquent ORM
- API Resource controllers

---

## 4. Arsitektur Frontend

Frontend menggunakan pola Clean Architecture yang terbagi per fitur.

### Struktur utama

- `lib/core/` : konfigurasi umum, routing, tema, network, exception, util
- `lib/shared/` : enum relasi role, reusable widget
- `lib/features/` : fitur utama app

### Pola umum per fitur

Setiap fitur biasanya punya:

- `data/` : model, datasource, repository implementation
- `domain/` : entity, repository interface, usecase
- `presentation/` : provider, screen, widget

Contoh yang paling jelas ada pada fitur `auth` dan `master_data`.

### Routing aplikasi

Router utama dijelaskan di `lib/core/router/app_router.dart`.

Rute utama:

- `/splash`
- `/login`
- `/dashboard`
- `/customers`
- `/services`
- `/transactions`
- `/collections` (halaman Pengambilan/Pelunasan)
- `/scan-qr`
- `/reports`
- `/users`
- `/settings`

Flow redirect:

1. aplikasi membuka splash
2. sistem mengecek session login
3. jika belum login -> redirect ke login
4. jika sudah login -> redirect ke dashboard sesuai role

---

## 5. Role & Akses Pengguna

Role user didefinisikan di `lib/shared/enums/user_role.dart`.

### Role yang ada

- `superOwner`
- `owner`
- `kasir`

### Hak akses

- `superOwner` dan `owner` dapat mengelola pengguna
- `superOwner` dan `owner` dapat melihat laporan
- `superOwner` dan `owner` dapat mengelola harga layanan
- `superOwner` bisa akses backup/restore dan akun khusus

Artinya, sistem sudah dibangun dengan konsep role-based access control.

---

## 6. Alur Login dan Session

### Frontend

User login melalui `LoginScreen` dan `auth_providers.dart`.

Alur:

1. user memasukkan username & password
2. `LoginUseCase` memanggil repository auth
3. repository mengakses `AuthRemoteDataSource`
4. frontend mengirim request ke API Laravel `/api/auth/login`
5. backend menghasilkan token Sanctum
6. token disimpan ke secure storage
7. sessionProvider diupdate
8. aplikasi pindah ke dashboard

### Session handling

- `sessionProvider` mengecek user yang sedang login
- splash screen digunakan untuk auto-login
- logout memutus token dan menghapus sesi

Ini ditangani di:

- `lib/features/auth/presentation/providers/auth_providers.dart`
- `lib/features/auth/data/datasources/auth_local_datasource.dart`
- `lib/core/network/dio_client.dart`

---

## 7. Fitur yang Sudah Diterapkan

## 7.1 Autentikasi & Session

Fitur yang sudah berjalan:

- splash screen
- login
- logout
- remember login
- auto login
- sesi user disimpan di storage
- redirect otomatis berdasarkan login status
- role-based dashboard navigation

### Penjelasan penggunaan

User membuka aplikasi, sistem mengecek apakah token/sesi masih valid. Jika valid, langsung masuk dashboard. Jika tidak, diarahkan ke login.

---

## 7.2 Dashboard

Dashboard dibuat per role:

- `SuperOwnerDashboardScreen`
- `OwnerDashboardScreen`
- `KasirDashboardScreen`

Semua dashboard menggunakan layout shell yang sama di `DashboardShell`, dengan:

- AppBar
- drawer navigation
- role-sensitive menu
- tombol logout
- bottom navigation yang tetap tampil pada halaman tab utama

Bottom navigation dibedakan menurut role:

- Kasir: Beranda, Transaksi, Scan QR, Pelanggan, Pengaturan.
- Owner/Super Owner: Beranda, Transaksi, Scan QR, Laporan, Pengaturan.

Tombol Scan QR berada di tengah sebagai tombol khusus yang lebih menonjol. Drawer (ikon burger) tetap dipertahankan sebagai akses seluruh menu, termasuk menu yang tidak berada di bottom navigation.

### Menu utama yang tergantung role

- Dashboard
- Transaksi
- Pelanggan
- Layanan Laundry
- Scan QR
- Laporan
- Manajemen User
- Pengaturan

---

## 7.3 Master Data Pelanggan

Data pelanggan diambil dari API Laravel.

Fitur:

- lihat daftar pelanggan
- tambah pelanggan baru
- detail pelanggan
- edit pelanggan
- cari pelanggan
- menampilkan total transaksi per pelanggan

### Struktur terkait

- `lib/features/master_data/domain/entities/customer_entity.dart`
- `lib/features/master_data/data/datasources/customer_remote_datasource.dart`
- `lib/features/master_data/presentation/screens/customers_screen.dart`
- `lib/features/master_data/presentation/screens/customer_detail_screen.dart`

### Data pelanggan di backend

Model `Customer` memiliki field:

- `name`
- `phone`
- `address`
- `gender`

Relasi:

- 1 pelanggan punya banyak transaksi

---

## 7.4 Master Data Layanan Laundry

Fitur ini sudah ada dan dibangun untuk mengelola jenis layanan laundry.

Fungsi:

- daftar layanan
- tambah layanan baru
- edit layanan
- hapus layanan (jika diterapkan di backend)
- pilih satuan: kg/item
- estimasi waktu pengerjaan
- harga layanan

### Data layanan

Backend `Service` model mendefinisikan:

- `name`
- `price`
- `unit`
- `estimation_hours`

### Alur bisnis

Ketika transaksi dibuat, user memilih jasa laundry dan jumlah kuantitas. Sistem akan menghitung subtotal dan total berdasarkan harga per satuan.

---

## 7.5 Modul Transaksi (Inti Bisnis)

Ini adalah fitur paling penting dari sistem.

### Fungsi yang sudah ada

- membuat transaksi baru
- memilih pelanggan
- memilih layanan
- mengisi jumlah/berat
- memilih metode pembayaran
- mengatur kondisi pembayaran (belum bayar, DP, lunas)
- melihat estimasi selesai
- melihat status laundry
- melihat transaksi sebelumnya
- filter transaksi melalui tombol dropdown
- filter periode pembuatan transaksi (tanggal dari--sampai)
- pencarian invoice, pelanggan, nomor telepon, atau layanan
- membuka detail transaksi
- QR invoice
- proses pengambilan/pelunasan pada halaman khusus

### Data transaksi mencakup

- customer
- nomor invoice
- total harga
- status pembayaran
- status laundry
- tanggal dibuat
- estimasi selesai
- catatan tambahan

### Logika status otomatis

Di `transaction_entity.dart` ada logic untuk menghitung status laundry berdasarkan `estimatedFinishAt` dan `createdAt`.

Status yang dipetakan:

- `received`
- `washing`
- `drying`
- `ironing`
- `completed`
- `collected`
- `late`

### Filter transaksi

Set di `TransactionsScreen`:

- Semua
- Hari Ini
- Diterima
- Diproses
- Selesai
- Belum Diambil
- Sudah Diambil
- Lunas
- Belum Lunas

Filter status dan periode dapat dipakai bersamaan. Tombol `Filter` berbentuk pill-outline berada di bawah search bar sisi kanan. Pada halaman Pengambilan, daftar otomatis hanya memuat transaksi yang belum diambil serta pilihan filter Sudah Diambil/Belum Diambil tidak ditampilkan.

### Flow transaksi

1. user masuk menu transaksi
2. user pilih pelanggan
3. user pilih layanan laundry
4. sistem menghitung subtotal otomatis
5. user pilih metode pembayaran & status pembayaran
6. transaksi disimpan ke backend
7. transaksi keluar ke daftar riwayat
8. status otomatis berubah sesuai estimasi selesai

---

## 7.6 Payment & Status Pembayaran

Model payment status di frontend:

- `unpaid` => Belum Bayar
- `downPayment` => DP
- `paid` => Lunas

Di backend Laravel, transaksi menyimpan:

- `payment_status` => `unpaid` atau `paid`

Jadi ada keselarasan umum antara frontend dan backend, meski beberapa status seperti DP belum sepenuhnya terluas di backend.

---

## 7.7 QR Code & Scan QR

Fitur sudah diterapkan untuk:

- generate QR invoice
- scan QR untuk membuka halaman Pengambilan/Pelunasan

### File utama

- `lib/features/transactions/presentation/screens/qr_scanner_screen.dart`
- `lib/features/transactions/presentation/screens/transactions_screen.dart`
- `lib/features/transactions/domain/entities/transaction_entity.dart`

### Fungsi bisnis

QR digunakan untuk memudahkan pengecekan transaksi tertentu dari pelanggan atau kasir tanpa harus mencari manual.

---

## 7.8 Riwayat Transaksi & Laporan

Fitur riwayat transaksi sudah dibentuk dengan daftar, filter, dan search. Laporan pencatatan pendapatan/operasional juga sudah disiapkan, dengan akses terbatas untuk role owner / super owner.

Sumber utama:

- `lib/features/reports/presentation/screens/reports_screen.dart`
- `lib/features/transactions/presentation/screens/transactions_screen.dart`

---

## 7.9 Manajemen User

Fitur manajemen user dibangun untuk role yang berwenang.

Fungsi umum:

- melihat daftar user
- melihat role user
- mengatur hak akses

Akses biasanya hanya untuk owner/superowner.

---

## 7.10 Pengaturan & Printer

Aplikasi sudah mempersiapkan pengaturan:

- profil laundry
- printer default
- perangkat printer bluetooth
- setting kertas/format bon

### File terkait

- `lib/features/settings/presentation/screens/settings_screen.dart`
- `lib/features/printing/presentation/providers/printing_providers.dart`
- `lib/features/printing/data/services/printer_device_service_native.dart`
- `lib/features/printing/data/services/thermal_receipt_service_native.dart`

### Fungsi cetak

Aplikasi menyiapkan dukungan untuk mencetak struk/bon thermal 58mm menggunakan printer bluetooth.

---

## 8. Alur Progres Fitur Secara Bertahap

Dari README project frontend, alur pengembangan yang sudah terjadi adalah:

### Tahap 1: Fondasi aplikasi

- Clean Architecture
- Riverpod
- GoRouter
- Material 3
- autologin
- role-based access
- splash login dashboard

### Tahap 2: Master Data

- pelanggan
- layanan laundry
- CRUD dasar

### Tahap 3: POS & transaksi

- transaksi baru
- mengatur item laundry
- kalkulasi biaya otomatis
- bayar tunai/QRIS/transfer
- detail transaksi
- status laundry

### Tahap 4: Riwayat & QR

- daftar riwayat transaksi
- scan QR
- invoice code

### Tahap 5: Administrasi & printer

- laporan
- manajemen user
- pengaturan profil dan printer
- cetak bon thermal

---

## 9. Backend Laravel: Struktur & Fitur

Backend Laravel yang ada di `D:\laragon\www\api-indafri-laundry` sudah menyediakan API yang konsisten dengan kebutuhan aplikasi mobile.

### Route API

Di `routes/api.php`, route utama dibuat seperti:

- `POST /api/auth/login`
- `POST /api/auth/logout`
- `GET /api/auth/me`

Lalu untuk fitur bisnis:

- `GET /api/customers`
- `POST /api/customers`
- `GET /api/customers/{id}`
- `PUT /api/customers/{id}`
- `DELETE /api/customers/{id}`

- `GET /api/services`
- `POST /api/services`
- `GET /api/services/{id}`
- `PUT /api/services/{id}`
- `DELETE /api/services/{id}`

- `GET /api/transactions`
- `POST /api/transactions`
- `GET /api/transactions/{id}`
- `PUT /api/transactions/{id}`
- `DELETE /api/transactions/{id}`

Semua route dibungkus dengan middleware `auth:sanctum` agar hanya user login yang bisa mengakses.

---

## 10. Backend: Model dan Relasi

### `User`

- Menggunakan `HasApiTokens` agar bisa membuat token API untuk mobile
- Login menghasilkan token Sanctum

### `Customer`

Relasi:

- hasMany Transaction

### `Service`

Representasi jenis layanan laundry. Masing-masing service punya:

- name
- price
- unit
- estimation_hours

### `Transaction`

Relasi:

- belongsTo Customer
- hasMany TransactionDetail

### `TransactionDetail`

Relasi:

- belongsTo Transaction
- belongsTo Service

Ini struktur data yang tepat untuk transaksi laundry multi-item.

---

## 11. Backend: Logic Controller

### AuthController

Fungsi:

- login user
- validasi username & password
- cek password dengan `Hash::check`
- buat token
- return user data + token

### CustomerController

Fungsi CRUD pelanggan:

- index
- store
- show
- update
- destroy

### ServiceController

Fungsi CRUD layanan laundry:

- index
- store
- show
- update
- destroy

### TransactionController

Fungsi CRUD transaksi:

- index: ambil semua transaksi dengan customer dan detail servis
- store: validasi payload dan simpan transaksi + detail transaksi
- show: detail satu transaksi
- update: update status pembayaran atau order_status
- destroy: hapus transaksi

### Catatan penting

Pada `TransactionController`, ketika transaksi baru dibuat, backend menghitung total dari semua item layanan lalu menyimpan detail per barang dengan:

- `transaction_id`
- `service_id`
- `qty`
- `price`
- `subtotal`

Jadi data transaksi bersifat detail-based dan cocok untuk laporan serta rekam jejak.

---

## 12. Database & Struktur Migrasi

Migrasi yang tersedia:

- create_users_table
- create_personal_access_tokens_table
- create_customers_table
- create_services_table
- create_transactions_table
- create_transaction_details_table

Ini menunjukkan bahwa backend memang dirancang untuk sistem laundry yang lengkap, bukan hanya demo.

---

## 13. Keselarasan Frontend dan Backend

Berikut keselarasan utamanya:

### 13.1 Auth

Frontend mengirim:

- username
- password

Backend mengembalikan:

- token
- user data
- role user

Frontend kemudian menyimpan token di secure storage dan menggunakan satu sesi login.

### 13.2 Pelanggan

Frontend memanggil API customers. Backend mengembalikan array pelanggan. UI menampilkan daftar kemudian detail dan form edit.

### 13.3 Layanan

Frontend memanggil API services. Backend memvalidasi:

- `name`
- `price`
- `unit`
- `estimation_hours`

UI mobile menyediakan form yang kompatibel dengan struktur ini.

### 13.4 Transaksi

Frontend mengirim payload yang isinya seperti:

- `customer_id`
- `payment_status`
- `services[]`
  - `service_id`
  - `qty`
  - `price`

Backend memvalidasi dan menyimpan transaksi bersama detail-itemnya.

Ini sudah sesuai dengan flow aplikasi POS laundry.

### 13.5 Status / pembayaran

Frontend punya status laundry dan status pembayaran; backend mendukung order_status & payment_status. Meskipun perhitungan status otomatis lebih rinci di frontend, backend sudah menyediakan dasar yang cukup untuk sinkronisasi.

---

## 14. Kelebihan yang Sudah Tercapai

- arsitektur aplikasi sudah jelas dan rapi
- alur login dan role berjalan
- modul master data sudah lengkap
- transaksi adalah inti bisnis dan sudah terintegrasi
- UI mobile sudah cukup matang untuk kebutuhan operasional dasar
- backend sudah ada dan sesuai kebutuhan
- integrasi frontend-backend sudah berfungsi dengan pola API REST jelas

---

## 15. Catatan Penting / Risiko yang Masih Perlu Diperhatikan

Beberapa area yang perlu tetap diawasi:

1. IP backend harus sesuai network device mobile.
2. Aplikasi Flutter harus punya internet permission dan cleartext traffic untuk Android jika backend memakai HTTP local.
3. Perhitungan status laundry di frontend dan backend belum 100% identik jika dipakai logika yang lebih detil.
4. Beberapa fitur admin (backup, restore, role lebih spesifik) masih perlu diperluas di backend.
5. Validasi payload / error handling harus tetap konsisten antara frontend dan backend.

---

## 16. Kesimpulan

Proyek ini sudah berjalan pada tingkat aplikasi laundry manajemen yang cukup matang untuk kebutuhan operasional nyata, bukan sekadar prototype.

Dari sisi frontend, sudah ada fondasi yang kuat untuk:

- auth,
- dashboard,
- pelanggan,
- layanan,
- transaksi,
- laporan,
- pengaturan dan printer.

Dari sisi backend Laravel, sudah ada struktur API yang mendukung seluruh kebutuhan tersebut dengan pendekatan MVC + Eloquent + Sanctum.

Artinya, proyek ini sudah berada dalam fase integrasi yang sehat dan dapat terus dikembangkan ke arah production-grade system dengan penyesuaian lanjut seperti:

- validasi lebih ketat,
- audit log,
- role permission lebih detail,
- backup restore,
- export PDF/Excel,
- notifikasi,
- log transaksi dan histori perubahan.

---

## 17. Detail Per Halaman Aplikasi dan Fungsi Tiap Tombol

Berikut ini penjelasan alur tiap halaman sesuai kondisi implementasi yang sudah dibuat. Fokusnya bukan hanya tampilan, tetapi fungsi tombol, navigasi, dan apa yang terjadi saat user menekan tiap elemen.

### 17.1 Splash Screen

Halaman ini muncul saat aplikasi dibuka.

Fungsi:

- menampilkan logo laundry dan nama aplikasi
- menampilkan loading spinner
- menjalankan pengecekan sesi user di background
- jika user sudah login, redirect ke dashboard
- jika belum login, redirect ke login screen

Pada implementasi, splash screen tidak melakukan navigasi manual sendiri. Navigasi justru diatur oleh router di `app_router.dart` dan `sessionProvider`.

Jadi alurnya:

1. aplikasi dibuka
2. splash screen tampil 1-2 detik
3. session dicek
4. router memutuskan arah ke dashboard atau login

---

### 17.2 Login Screen

Halaman login adalah titik masuk utama jika user belum login.

Elemen yang ada:

- icon aplikasi di bagian atas
- judul "Selamat Datang"
- deskripsi singkat
- form login berisi username dan password
- tombol login

Fungsi:

- menerima username dan password
- mengirim ke backend Laravel `/api/auth/login`
- backend mengecek validitas user
- jika sukses, token dan data user diterima
- token disimpan ke secure storage
- user diarahkan ke dashboard sesuai role

Jika login gagal, aplikasi menampilkan error message dan user tetap di halaman login.

---

### 17.3 Dashboard (Owner, Kasir, Super Owner)

Dashboard adalah halaman rumah setelah login. Dashboard dibuat berbeda tergantung role user.

#### 17.3.1 Dashboard Owner

Tampilan berisi kartu-kartu ringkasan seperti:

- Pendapatan Hari Ini
- Pendapatan Bulan Ini
- Jumlah Transaksi
- Total Pelanggan
- Laundry Diproses
- Belum Diambil

Tujuan:

- owner bisa melihat performa usaha secara cepat
- owner bisa mengevaluasi cashflow dan status operasional laundry

Button yang paling penting di dashboard ini:

- menu drawer di kiri atas
- tombol logout di kanan atas

Menu drawer berisi:

- Dashboard
- Transaksi
- Pelanggan
- Layanan Laundry
- Scan QR
- Riwayat Transaksi
- Laporan
- Manajemen User
- Pengaturan

Saat user menekan salah satu item, aplikasi akan berpindah ke screen terkait.

Contoh:

- tombol `Transaksi` -> ke halaman daftar transaksi
- tombol `Pelanggan` -> ke halaman pelanggan
- tombol `Layanan Laundry` -> ke screen kelola service
- tombol `Laporan` -> ke halaman laporan pendapatan
- tombol `Pengaturan` -> ke halaman pengaturan bisnis/printer

#### 17.3.2 Dashboard Kasir

Dashboard kasir fokus pada operasional harian. Kartu statistiknya seperti:

- Transaksi Hari Ini
- Laundry Diproses
- Laundry Selesai
- Belum Diambil

Fungsi utama:

- kasir cepat melihat pekerjaan yang harus ditangani hari itu
- kasir dapat langsung membuat transaksi baru dari tombol `Transaksi Baru`
- kartu statistik dapat ditekan dan membuka halaman Transaksi dengan filter yang sesuai

Pemetaan kartu statistik:

- `Transaksi Hari Ini` -> Hari Ini
- `Laundry Diproses` -> Diproses
- `Laundry Selesai` -> Selesai
- `Belum Diambil` -> Belum Diambil

Button yang penting:

- `Transaksi Baru` -> membuka halaman pembuatan transaksi baru
- `Ambil/Pelunasan` -> menampilkan pilihan Scan QR atau Cari Transaksi
- tombol logout -> keluar aplikasi
- drawer menu -> sama seperti owner, tetapi akses menu tertentu dibatasi role

Navigasi utama memakai bottom navigation. Isi halaman bergeser mengikuti arah tab tujuan, sedangkan bottom navigation tetap diam. Tombol back perangkat dari tab selain Beranda kembali ke Beranda; dari Beranda aplikasi menampilkan dialog konfirmasi keluar.

#### 17.3.3 Dashboard Super Owner

Pada implementasi, super owner memakai layout dashboard owner, karena super owner punya akses seluruh menu dan fitur administratif penuh.

Perbedaannya:

- dia bisa melihat semua fitur owner
- menu tambahan untuk backup/restore dan manajemen user muncul karena role ini memiliki akses spesial
- dia punya hak akses paling tinggi dibanding role lain

---

### 17.4 Halaman Pelanggan

Halaman ini berisi daftar semua pelanggan yang tersimpan di database backend.

Fungsi tombol dan elemen:

- tombol search di AppBar -> mencari pelanggan dari daftar yang sudah ada
- tombol floating `Tambah` di bagian bawah -> membuka form untuk menambahkan pelanggan baru
- setiap card pelanggan -> klik untuk membuka detail pelanggan
- icon edit di sisi kanan card -> mengubah data pelanggan
- long press / tahan card -> menghapus pelanggan (hanya untuk role yang punya hak)

Flow lengkap:

1. user buka menu Pelanggan
2. aplikasi memanggil API pelanggan dari backend
3. daftar tampil dalam bentuk list card
4. jika user klik card, masuk ke detail pelanggan
5. jika user klik `Tambah`, muncul bottom sheet form
6. setelah simpan, data dikirim ke backend dan list refresh otomatis

Pada halaman pelanggan, kasir biasanya tidak bisa menghapus pelanggan karena hak akses dibatasi.

---

### 17.5 Detail Pelanggan

Halaman detail pelanggan menampilkan informasi rinci seperti:

- nama pelanggan
- nomor HP
- alamat
- jenis kelamin
- jumlah transaksi yang pernah dilakukan

Tujuan:

- memudahkan admin/kasir melihat riwayat pelanggan
- memudahkan saat membuat transaksi baru karena data pelanggan sudah mudah dikenali

Biasanya halaman ini dibuka dari daftar pelanggan ketika user tap card pelanggan.

---

### 17.6 Halaman Layanan Laundry

Halaman ini berisi daftar semua jenis layanan laundry yang tersedia.

Contoh layanan misalnya:

- Cuci Kiloan
- Setrika
- Dry Clean
- Express Service
- dll

Elemen yang ada:

- AppBar berjudul `Layanan Laundry`
- tombol floating `Tambah` -> menambah layanan baru
- list card layanan dengan nama, harga, unit, estimasi waktu
- klik card -> buka form edit
- long press -> hapus layanan

Fungsi utamanya:

- mengatur daftar produk jasa laundry
- menentukan harga layanan
- menentukan satuan (kg/item)
- menentukan estimasi selesai

Ketika membuat transaksi, user memilih layanan dari daftar ini, lalu aplikasi otomatis menghitung subtotal dan estimasi selesai berdasarkan harga dan estimasi waktu yang sudah diatur.

---

### 17.7 Halaman Transaksi Baru

Ini adalah halaman inti dari aplikasi.

Fungsi utamanya adalah membuat transaksi laundry baru.

Urutan langkah pada halaman ini:

1. `Pilih pelanggan`
   - user memilih nama pelanggan dari daftar
   - jika belum ada pelanggan, ada tombol `Tambah pelanggan baru`

2. `Pilih layanan`
   - user memilih layanan laundry yang akan diproses
   - aplikasi menampilkan estimasi selesai sesuai layanan yang dipilih

3. `Masukkan jumlah atau berat`
   - sesuai jenis service, bisa berbentuk jumlah item atau berat kg

4. `Layanan Express`
   - toggle `Layanan Express`
   - akan menambah biaya 25% sesuai implementasi

5. `Catatan (opsional)`
   - user bisa menulis catatan tambahan untuk laundry

6. `Metode pembayaran`
   - pilihan: Tunai, QRIS, Transfer

7. `Status pembayaran`
   - pilihan: Belum Bayar, DP, Lunas

8. `Ringkasan harga`
   - subtotal
   - express fee
   - total akhir

9. Tombol `Simpan Transaksi`
   - data dikirim ke backend
   - transaksi dibuat dan ditampilkan di daftar transaksi

Jika semua input valid, transaksi berhasil tersimpan lalu aplikasi kembali ke daftar transaksi.

---

### 17.8 Halaman Daftar Transaksi

Halaman ini menampilkan semua transaksi yang sudah dibuat.

Fitur yang ada:

- search bar untuk invoice, pelanggan, nomor HP, atau layanan
- tombol pill `Filter` di bawah search bar sisi kanan
- panel filter berisi dropdown status dan periode pembuatan transaksi dari tanggal--sampai tanggal
- tombol floating `Transaksi Baru` untuk menambah transaksi baru
- daftar card transaksi

Setiap card transaksi menampilkan:

- nama pelanggan
- nomor invoice
- nama layanan
- estimasi selesai
- total tagihan
- status laundry
- status pembayaran

Saat user menekan card transaksi, aplikasi membuka halaman detail transaksi.

---

### 17.9 Detail Transaksi

Halaman detail transaksi adalah halaman kontrol utama setelah transaksi dibuat.

Yang ada di halaman ini:

- QR code invoice
- nama pelanggan dan nomor HP
- nama layanan dan qty
- tanggal masuk
- estimasi selesai
- status laundry
- status pembayaran
- total biaya
- tombol `Hubungi via WhatsApp`
- tombol `Cetak Bon`
- menu `Hapus transaksi` jika role cocok

Status laundry dan pembayaran pada halaman ini bersifat informasi otomatis/read-only. Kasir tidak dapat mengubahnya dari halaman detail transaksi. Serah-terima dan pelunasan hanya dilakukan dari halaman Pengambilan/Pelunasan.

Fungsi tombol penting:

#### Hubungi via WhatsApp
- membuka WhatsApp ke nomor pelanggan
- text otomatis memuat info transaksi

#### Cetak Bon
- otomatis mengirim data transaksi ke printer Bluetooth yang sudah diatur di pengaturan
- mencetak struk laundry sesuai format thermal

---

### 17.10 Halaman Pengambilan/Pelunasan

Halaman ini khusus untuk menyelesaikan serah-terima laundry dan pembayaran. Halaman dibuka dari menu `Pengambilan`, hasil scan QR invoice, atau card transaksi pada daftar Pengambilan.

Halaman berisi:

- bagian `Bukti pengambilan` dengan tombol kamera dan pratinjau foto
- kode invoice dalam teks, tanpa QR code
- nama serta nomor telepon pelanggan
- detail tagihan: total, sudah dibayar, dan sisa tagihan
- tombol bersebelahan `Ambil Saja` dan `Lunasi`

Bukti foto wajib diambil terlebih dahulu. Foto dikompresi lalu disimpan secara lokal pada perangkat memakai `shared_preferences`; bukti ini belum diunggah ke backend Laravel.

Perilaku tombol:

- `Ambil Saja`: mengubah status laundry menjadi `collected`, tanpa mengubah kondisi pembayaran.
- `Lunasi`: mengubah status laundry menjadi `collected`, pembayaran menjadi `paid`, dan nominal terbayar disamakan dengan total transaksi.

Sebelum penyimpanan, aplikasi menampilkan dialog konfirmasi. Setelah berhasil, halaman kembali ke daftar Pengambilan sehingga transaksi tersebut tidak lagi tampil pada daftar transaksi belum diambil.

### 17.11 Halaman Scan QR

Halaman ini digunakan untuk scan QR code dari bon laundry.

Fungsi:

- membuka kamera
- mendeteksi QR code
- membandingkan hasil scan dengan nomor invoice transaksi yang ada di database
- jika cocok, aplikasi langsung membuka halaman Pengambilan/Pelunasan transaksi tersebut
- jika tidak ada, aplikasi menampilkan pesan `Transaksi dengan kode tersebut tidak ditemukan.`

Flow:

1. user masuk menu Scan QR
2. kamera aktif
3. user arahkan ke QR kode pada bon laundry
4. aplikasi membaca invoice
5. aplikasi mencari transaksi yang punya invoice sama
6. jika ada, halaman Pengambilan/Pelunasan dibuka otomatis

Ini berguna untuk pengecekan transaksi tanpa mencari manual di list transaksi.

---

### 17.12 Halaman Laporan

Halaman laporan digunakan untuk melihat ringkasan performa usaha.

Informasi yang ditampilkan:

- Pendapatan Hari Ini
- Pendapatan Bulan Ini
- Total transaksi
- Laundry diproses
- Belum diambil
- layanan terlaris

Fungsi tombol:

- `Export laporan` -> tombol yang sudah disiapkan, tetapi belum sepenuhnya dihubungkan ke export file PDF/Excel

Fungsi halaman ini adalah memberikan gambaran performa untuk owner dan super owner agar bisa mengecek profit dan operasional laundry.

---

### 17.13 Halaman Manajemen User

Halaman ini terbatas untuk role owner/super owner.

Fungsinya:

- melihat daftar user akun
- melihat role tiap user
- mengatur status aktif/nonaktif user
- menambah user baru
- mengedit user

Button penting:

- tombol `Tambah` di bawah -> menambah user baru
- switch aktif/nonaktif -> mengontrol status akun
- tap card user -> edit profil dan role user

Ini penting untuk kontrol hak akses dan pengelolaan karyawan laundry.

---

### 17.14 Halaman Pengaturan

Halaman pengaturan digunakan untuk mengatur data bisnis dan printer.

Form yang ada:

- Nama laundry
- Nomor telepon laundry
- Alamat laundry
- ukuran kertas struk
- printer Bluetooth default

Fungsi tombol:

- `Pilih printer Bluetooth` -> menampilkan daftar printer yang sudah terpasang ke perangkat
- `Simpan pengaturan` -> menyimpan konfigurasi ke local storage / settings repository

Tujuannya:

- menyesuaikan identitas usaha atau brand laundry
- memastikan printer yang dipakai saat print bon benar
- memastikan format struk sesuai kebutuhan

---

### 17.15 Hubungan Antara Halaman-Halaman Utama

Secara umum, alur navigasi utama aplikasi adalah:

1. Splash Screen -> pengecekan session
2. Login -> masuk ke dashboard
3. Dashboard -> pilih menu
4. Transaksi -> pilih pelanggan + layanan -> simpan transaksi
5. Daftar transaksi -> klik transaksi -> detail transaksi
6. Detail transaksi -> lihat informasi, hubungi pelanggan, cetak bon
7. Pengambilan/Pelunasan -> ambil bukti foto, serahkan laundry, dan/atau lunasi
7. Pelanggan dan Layanan -> data pendukung untuk transaksi
8. Laporan -> ringkasan performa usaha
9. Pengaturan -> konfigurasi printer dan profil usaha
10. Manajemen User -> akses admin untuk role tertentu

Dengan begitu, aplikasi ini masuk kategori POS + manajemen laundry yang memiliki alur bisnis yang jelas, bukan sekadar halaman statis.

---

## 18. Sumber Utama dalam Proyek

Beberapa file kunci yang menjadi referensi utama:

- `laundry_app/README.md`
- `laundry_app/lib/core/router/app_router.dart`
- `laundry_app/lib/features/auth/presentation/providers/auth_providers.dart`
- `laundry_app/lib/features/transactions/presentation/screens/transactions_screen.dart`
- `laundry_app/lib/features/transactions/presentation/providers/transaction_providers.dart`
- `laundry_app/lib/core/constants/app_constants.dart`
- `laundry_app/lib/shared/enums/user_role.dart`
- `D:\laragon\www\api-indafri-laundry\routes\api.php`
- `D:\laragon\www\api-indafri-laundry\app\Http\Controllers\Api\AuthController.php`
- `D:\laragon\www\api-indafri-laundry\app\Http\Controllers\Api\CustomerController.php`
- `D:\laragon\www\api-indafri-laundry\app\Http\Controllers\Api\ServiceController.php`
- `D:\laragon\www\api-indafri-laundry\app\Http\Controllers\Api\TransactionController.php`

Dokumentasi ini dibuat untuk membantu mengingat kembali alur aplikasi, alur fitur, serta hubungan frontend-backend secara utuh.
