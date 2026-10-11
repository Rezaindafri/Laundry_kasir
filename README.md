# KarsaOne

Aplikasi kasir dan manajemen operasional berbasis Flutter dengan REST API Laravel. Branding sudah KarsaOne; paket, folder, tabel, dan istilah layanan laundry yang ada dipertahankan agar tidak memutus integrasi/data.

Terakhir diverifikasi: backend **9–10 Oktober 2026**, Flutter **11 Oktober 2026**. Backend nyata sudah digunakan, bukan proyek mock-only. Integrasi utama berjalan, tetapi audit menemukan bug dan celah keamanan yang masih terbuka. Jangan menganggap proyek siap produksi hanya karena tes utama lulus.

## Lokasi dan stack

| Bagian | Lokasi / teknologi |
| --- | --- |
| Flutter | C:\Android\ProjekOM\laundry_app; Riverpod, GoRouter, Dio, Material 3 |
| Laravel | D:\laragon\www\api-indafri-laundry; PHP ^8.3, Laravel ^13.8, Sanctum ^4.0 |
| Database | MySQL untuk aplikasi; SQLite :memory: khusus pengujian |
| Branding | KarsaOne, aksen biru, permukaan putih, logo dan splash animasi |
| Konfigurasi | lib/core/constants/app_constants.dart; useMockApi = false |

URL saat audit masih HTTP/IP LAN untuk pengembangan. HP mengakses Laravel melalui jaringan, bukan langsung ke MySQL. Deployment perlu HTTPS dan document root Laravel public/.

## Peran dan fitur saat ini

| Peran | Cakupan |
| --- | --- |
| Kasir / User | Pelanggan baru, transaksi, DP/pelunasan, pengambilan, bon/QR, dashboard operasional kelompoknya. Tidak mengelola akun atau mengubah username/password sendiri. |
| Owner | Operasional kelompok sendiri, layanan/pelanggan, akun kasir sendiri, dashboard/filter, laporan pembayaran/CSV, pengeluaran, riwayat perubahan, konfigurasi usaha. |
| Super Owner | Struktur Owner → Kasir, pembuatan/pemindahan/aktivasi akun, kebijakan akun dan pengaturan sistem. **Tidak memiliki dashboard monitoring transaksi atau laporan operasional.** |

Data operasional menggunakan owner_id. Pemeriksaan izin dilakukan di Laravel, bukan hanya menu Flutter. Tes membuktikan penolakan beberapa akses lintas-owner; pemetaan seluruh data lama di database nyata tetap perlu diverifikasi sebelum deployment.

Fitur yang telah terhubung ke Laravel:

- Login Sanctum; pesan salah kredensial, akun nonaktif, dan kegagalan umum.
- CRUD pelanggan/layanan sesuai role; filter dan pagination transaksi server-side.
- Satu transaksi/bon dapat memuat beberapa layanan, masing-masing dengan kuantitas, harga dan estimasi sendiri dari backend. Estimasi keseluruhan memakai waktu selesai paling akhir, bukan penjumlahan durasi.
- Form Transaksi Baru memakai satu bagian Layanan: satu kartu awal, kartu tambahan seragam lewat tombol Tambah layanan, dan Express di bawah seluruh daftar. Minimal satu layanan tetap wajib.
- Pilihan pelanggan/layanan mengikuti pemuatan API, bukan salinan daftar kosong saat pencarian dibuka. Tersedia status memuat/gagal/kosong, coba lagi, dan tombol perbarui tanpa menutup pencarian. Nama diurutkan A–Z tanpa memperhitungkan nomor HP; kartu layanan terpilih juga A–Z dengan jumlah/berat tetap melekat pada layanan.
- “Bayar Saja” menerima nominal tambahan, metode dan catatan tanpa mengambil barang. DP/pelunasan dicatat sebagai event pembayaran pada waktu uang diterima.
- Pengambilan dapat bertahap per layanan yang sudah siap; DP sebelumnya diperhitungkan dan bon baru ditutup setelah semua layanan diambil. Foto tetap opsional dan tersimpan per pengambilan.
- Estimasi layanan boleh 0/kosong untuk barang tanpa proses: langsung siap, tanpa tenggat keterlambatan. Bon cetak/gambar menampilkan estimasi masing-masing layanan.
- Status berbasis waktu di backend dan scheduler laundry:sync-statuses.
- Dashboard Owner/Kasir, laporan pembayaran bertanggal, ekspor CSV, filter akun termasuk Me.
- Periode laporan memakai WIB; timestamp tetap UTC. Bukti pengambilan diakses melalui API berizin, file baru disimpan privat.
- Pengeluaran Owner dengan tanggal/waktu pilihan dan rincian laporan; belum ada status rencana/dibayar terpisah.
- Audit perubahan akun, transaksi dan pengeluaran; profil/settings usaha.
- Backup/restore **konfigurasi usaha**, bukan backup database/transaksi.
- Bon foto/WhatsApp dan printer Bluetooth memiliki implementasi Android; pengujian perangkat nyata masih diperlukan.
- Back menutup popup/drawer dahulu, lalu kembali satu halaman/tab. Konfirmasi keluar hanya pada Beranda tanpa riwayat sebelumnya. Form menunggu pelepasan overlay sebelum membuang controller; navigasi dikunci sementara selama penyimpanan. Scanner memakai controller kamera yang sama untuk preview/stop/galeri dan mengabaikan respons lookup setelah ditutup.

“Ingat saya” dibatasi 30 hari lokal, dan token Laravel juga kedaluwarsa setelah 30 hari. Startup memverifikasi sesi melalui `/auth/me`, bukan mempercayai role akun lokal.

## Menjalankan pengembangan

Scaffolding Android/iOS/web sudah ada. Tidak perlu membuat ulang proyek dengan flutter create.

Di Flutter:

~~~powershell
cd C:\Android\ProjekOM\laundry_app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
~~~

Perintah tersebut adalah panduan setup, bukan daftar perintah yang dijalankan audit. Pilih baseUrl sesuai server lokal. Jangan menaruh password/API key rahasia di konstanta Flutter.

Backend memerlukan .env lokal privat, PHP/ekstensi sesuai Composer, serta MySQL aktif. Siapkan dependensi dari composer.lock. Untuk database berisi data: tinjau migrasi, siapkan backup terpisah, lalu gunakan migrasi maju setelah persetujuan; jangan reset database atau menjalankan seeder akun demo di produksi.

Scheduler terdaftar setiap menit di routes/console.php. Hosting perlu memanggil php artisan schedule:run tiap menit; interval cron lebih jarang menunda pembaruan saat tidak ada request. Jangan menjalankannya saat audit read-only terhadap database nyata karena perintah itu memperbarui status.

## Hasil verifikasi terbaru

| Pemeriksaan | Hasil |
| --- | --- |
| PHPUnit backend + regresi baru | **87 lulus**, 621 assertions, SQLite di memori; termasuk multi-layanan, DP/pengambilan bertahap dan migrasi legacy |
| Tes audit tambahan dengan token login asli | **13/13 lulus**, 105 assertions; sebelumnya 9 kasus gagal |
| Flutter unit/widget | **97 lulus**, termasuk 29 regresi Back/popup/scanner/penyimpanan tertunda, pilihan saat API lambat, urutan A–Z, cache antar-sesi, pembayaran, bon, login dan WIB |
| Analisis Dart | Pemeriksaan menyeluruh sebelumnya: 0 error, 12 warning lama. 13 file perubahan navigasi/form dan tes diperiksa 11 Oktober: 0 error/warning, 343 lint/hint informasi |
| Composer audit lockfile (runtime dan seluruh paket) | **0 advisori**, setelah upgrade terarah tiga paket |

Tes UI memakai repository palsu, sedangkan tes API menjalankan Laravel dengan data sintetis. Belum ada pengujian end-to-end Flutter → server hosting nyata atau seluruh perangkat.

## Penanganan audit dan pekerjaan tersisa

- Logout/revokasi, expiry token, rate limit login dan validasi sesi Flutter sudah diperbaiki.
- Token contoh disanitasi dan fingerprint token terpapar diblokir Sanctum. **Riwayat Git lama belum dibersihkan; tidak mencabut baris token nyata atau merotasi kredensial.**
- Status `collected` terminal; pembayaran/pengambilan dan scheduler membaca ulang dengan row lock. Retry saldo kumulatif tidak menambah ledger/audit; request paralel MySQL belum diuji.
- Restore atomik, guard downgrade Owner bertanggungan, pesan error generik dan escape formula CSV sudah diuji di Laravel.
- Batas tanggal WIB/UTC serta akses bukti privat/scoped sudah diterapkan. Aturan penolakan URL bukti lama tersedia untuk Apache dan artisan serve; konfigurasi hosting/Nginx, cache dan atribusi legacy masih perlu diverifikasi.
- Express dikirim per layanan dan dihitung +25% di Laravel; unit hari dikonversi ke jam saat mengatur estimasi. Controller scanner sudah dipasang ke widget kamera, dengan pause/resume dan perlindungan respons setelah Back; perilaku kamera/predictive Back Android nyata belum diverifikasi.
- Migrasi multi-layanan sudah diterapkan maju pada Laragon. Checksum kolom data lama sebelum/sesudah tetap sama; tidak reset, seed atau menghapus transaksi/pelanggan. Pengambilan sebagian berlaku untuk seluruh kuantitas satu baris layanan, belum sebagian kuantitas pada baris yang sama.
- Laravel 13.35.0, CommonMark 2.10.3 dan Flysystem 3.36.0 sudah terpasang dari lockfile terbaru; audit advisori perlu tetap dijalankan berkala.

Lihat [penyelarasan WIB, bukti dan dependensi](docs/TIMEZONE_BUKTI_DEPENDENSI_2026-10-10.md), [penanganan tahap pertama](docs/PERBAIKAN_PRIORITAS_2026-10-10.md) dan [audit awal](docs/AUDIT_INTEGRASI_KEAMANAN_2026-10-10.md). Tahap ini tidak menyelesaikan seluruh temuan atau membuktikan aplikasi siap produksi.

Kontrak, contoh DP/pengambilan bertahap dan batasan migrasi: [multi-layanan dan pembayaran](docs/MULTI_LAYANAN_PEMBAYARAN_2026-10-10.md).

Perbaikan lifecycle, urutan Back dan batas verifikasi: [navigasi Back](docs/NAVIGASI_BACK_2026-10-11.md).

## Pengujian aman

Flutter:

~~~powershell
flutter test --no-pub
dart analyze lib test
~~~

Backend, dalam PowerShell baru agar variabel testing tidak terbawa ke proses aplikasi:

~~~powershell
cd D:\laragon\www\api-indafri-laundry
$env:APP_ENV = 'testing'
$env:DB_CONNECTION = 'sqlite'
$env:DB_DATABASE = ':memory:'
$env:DB_URL = ''
$env:CACHE_STORE = 'array'
$env:SESSION_DRIVER = 'array'
$env:QUEUE_CONNECTION = 'sync'
php vendor/bin/phpunit --do-not-cache-result
php vendor/bin/phpunit --do-not-cache-result C:\Android\ProjekOM\laundry_app\tools\audit\BackendSecurityAuditTest.php
~~~

Jangan gunakan perintah tersebut jika bootstrap/cache/config.php masih mengarahkan testing ke database aplikasi. Tes audit/regresi keamanan baru menolak konfigurasi selain SQLite di memori. Tes diagnostik terpisah kini lulus setelah perbaikan kasusnya; tidak menggantikan E2E atau pengujian concurrency MySQL.

Pemeriksaan advisori tanpa upgrade:

~~~powershell
composer audit --locked --no-dev --format=json
~~~

## Dokumen dan Git

- [Dokumentasi teknis terbaru](DOKUMENTASI_PROYEK_LAUNDRY.md).
- [Audit integrasi dan keamanan](docs/AUDIT_INTEGRASI_KEAMANAN_2026-10-10.md).
- [Penanganan prioritas dan hasil regresi](docs/PERBAIKAN_PRIORITAS_2026-10-10.md).
- [WIB/UTC, bukti privat, upgrade dan langkah deployment](docs/TIMEZONE_BUKTI_DEPENDENSI_2026-10-10.md).
- Backend_Needed.md: catatan historis kebutuhan; verifikasi terhadap kode/dokumen terbaru sebelum mengikutinya.

.gitignore diperluas pada kedua repositori untuk varian .env, kunci privat/signing, konfigurasi HTTP privat, cache/log dan backup lokal. Lockfile dependensi, source, migrasi, aset aplikasi dan tes tetap disimpan di Git. Ignore tidak menghapus file yang telanjur tracked.

Aturan ignore backend `api-indafri-laundry` sudah diverifikasi untuk env, vendor, bukti privat/public, log, SQLite dan dump SQL. `.env` nyata tidak tracked di kedua repo; `api_test.http` backend masih tracked dan history lamanya perlu penanganan terkoordinasi. Tidak menghapus data atau mengubah indeks/history Git pada tahap ini.
