# KarsaOne

Aplikasi kasir dan manajemen operasional berbasis Flutter dengan REST API Laravel. Branding sudah KarsaOne; paket, folder, tabel, dan istilah layanan laundry yang ada dipertahankan agar tidak memutus integrasi/data.

Terakhir diverifikasi: Flutter **21 Oktober 2026**; hasil backend di bawah adalah snapshot pengujian sebelumnya. Backend nyata sudah digunakan, bukan proyek mock-only. Integrasi utama berjalan, tetapi beberapa temuan audit dan verifikasi deployment masih terbuka. Jangan menganggap proyek siap produksi hanya karena tes utama lulus.

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
- Owner mengatur QRIS dan beberapa rekening melalui Setting → Tujuan pembayaran. Pilihan QRIS/transfer pada Transaksi Baru, Bayar Saja dan Bayar & Ambil menampilkan gambar QRIS atau bank/nomor rekening/pemilik; tunai tidak berubah. Rekening dienkripsi di database Laravel; gambar QRIS privat dan akses dibatasi kelompok Owner/Kasir. Pilihan tujuan tersimpan pada ledger pembayaran, bukan hanya UI.
- Nominal pembayaran terisi otomatis: total tagihan di Transaksi Baru, sisa seluruh tagihan di Bayar Saja, dan kebutuhan bayar layanan terpilih setelah DP di Bayar & Ambil. Tap memilih seluruh angka otomatis agar ketikan menggantinya; nominal manual tidak ditimpa perubahan layanan/berat/Express. Pembayaran awal penuh menjadi Lunas, sebagian menjadi DP; Belum Bayar tetap tanpa pembayaran.
- Pengambilan dapat bertahap per layanan yang sudah siap; DP sebelumnya diperhitungkan dan bon baru ditutup setelah semua layanan diambil. Foto tetap opsional dan tersimpan per pengambilan.
- Setelah pembayaran/pengambilan berhasil, aplikasi kembali ke pencarian Pengambilan dan memuat ulang query backend. Transaksi yang seluruhnya diambil hilang dari daftar; pembayaran saja/pengambilan sebagian tetap muncul dengan status terbaru. Pencarian dan filter halaman asal dipertahankan, dan Back tidak membuka ulang formulir yang sudah selesai.
- Daftar transaksi/Pengambilan dapat ditarik ke bawah untuk refresh, termasuk saat kosong, pendek atau gagal dimuat. Respons pagination dari query lama diabaikan setelah refresh; halaman berikutnya tetap dapat dimuat otomatis saat scroll atau melalui tombol.
- Halaman data dimuat ulang saat dibuka/dikunjungi kembali, termasuk perpindahan tab dan Back dari halaman lain. Filter/pencarian/draft tetap dipertahankan; menutup dialog atau bottom sheet tidak memicu reload halaman induk. Ini refresh berbasis navigasi, bukan websocket atau polling background.
- Detail Transaksi mengambil detail langsung dari Laravel dan menampilkan bagian Bukti pengambilan (pratinjau + foto per layanan) serta Riwayat pembayaran (tanggal, metode, tujuan dan pencatat bila tersedia). Foto yang sudah ada adalah bukti pengambilan, bukan bukti transfer; foto tetap opsional. Data lama tanpa informasi diberi keterangan, tidak ditebak.
- Estimasi layanan boleh 0/kosong untuk barang tanpa proses: langsung siap, tanpa tenggat keterlambatan. Bon cetak/gambar menampilkan estimasi masing-masing layanan.
- Status berbasis waktu di backend dan scheduler laundry:sync-statuses.
- Dashboard Owner/Kasir, laporan pembayaran bertanggal, ekspor CSV, filter akun termasuk Me. Laporan memiliki cache respons Laravel/prefetch terbatas per periode dan akun: cache hit langsung tampil, pilihan baru hanya memuat area hasil; respons lama tidak menimpa pilihan/sesi terbaru.
- Periode laporan memakai WIB; timestamp tetap UTC. Bukti pengambilan diakses melalui API berizin, file baru disimpan privat.
- Pengeluaran Owner dengan tanggal/waktu pilihan dan rincian laporan; belum ada status rencana/dibayar terpisah.
- Audit perubahan akun, transaksi dan pengeluaran; profil/settings usaha.
- Backup/restore **konfigurasi usaha**, bukan backup database/transaksi.
- Bon foto/WhatsApp dan printer Bluetooth memiliki implementasi Android; pengujian perangkat nyata masih diperlukan.
- Catatan bon cetak/gambar mencakup pengambilan/pembayaran transaksi. Caption WhatsApp memakai nama pelanggan/usaha, nomor transaksi dan total seluruh pesanan (format tebal WhatsApp), bukan nominal DP atau sisa tagihan. Pengaturan usaha ditunggu sebelum pilihan bon dibuka agar nama usaha dan printer tersimpan tersedia sejak pemakaian pertama. Layout struk memakai QR/identitas berdampingan dan jeda cetak akhir dikurangi dari delapan menjadi dua baris, tanpa menghilangkan rincian tagihan/estimasi.
- Printer terakhir langsung tersimpan saat dipilih (lokal per perangkat, tanpa menyimpan draft usaha). Izin runtime CONNECT+SCAN diperiksa sebelum connect/cetak; pemilih printer dibatasi tinggi dan dapat di-scroll. Pembatalan draft form dan tindakan destruktif memakai konfirmasi; form kosong/pencarian tetap ditutup normal, kecuali pembuatan layanan baru yang selalu dikonfirmasi. Simpan layanan menunggu hasil API dan mempertahankan isian saat gagal. Detail: [printer dan konfirmasi](docs/PRINTER_KONFIRMASI_2026-10-21.md), [revisi layanan/Laporan/struk](docs/PERBAIKAN_LAYANAN_LAPORAN_STRUK_2026-10-22.md).
- Request gagal jaringan/5xx diberi notifikasi singkat terpusat, timeout kirim/terima, dan deduplikasi notifikasi. Write tidak diulang otomatis: koneksi putus tidak membuktikan server gagal menyimpan, sehingga pengguna diminta memeriksa data terbaru dahulu.
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
| PHPUnit backend + regresi baru | **95 lulus**, 707 assertions, SQLite di memori; termasuk 8 tes tujuan pembayaran (86 assertions), enkripsi, QRIS privat, isolasi Owner, rollback dan retry |
| Tes audit tambahan dengan token login asli | **13/13 lulus**, 105 assertions; sebelumnya 9 kasus gagal |
| Regresi Laravel pembayaran, pengambilan bertahap dan isolasi owner (11 Oktober) | **3 lulus**, 35 assertions, SQLite di memori; endpoint tetap memakai validasi backend yang ada |
| Flutter unit/widget | **199 lulus (22 Oktober)**; tambahan regresi konfirmasi/simpan layanan, cache dan race condition Laporan, timeout/notifikasi request, layout/byte struk 58/80 mm; regresi caption/WhatsApp, printer, pembayaran, navigasi dan auth tetap lulus |
| Analisis Dart lib + test | **0 error, 11 warning lama**; lint/hint gaya masih tersedia, bukan klaim proyek bebas masalah. Warning tersisa pada model auth dan dashboard Owner lama |
| Composer audit lockfile (runtime dan seluruh paket) | **0 advisori**, setelah upgrade terarah tiga paket |

Tes UI memakai repository palsu, sedangkan tes API menjalankan Laravel dengan data sintetis. Belum ada pengujian end-to-end Flutter → server hosting nyata atau seluruh perangkat.

Nominal otomatis diuji dengan simulasi ketikan IME, perubahan tagihan, pengambilan sebagian/terakhir/sudah lunas, batas nominal dan retry pembayaran. Perilaku keyboard fisik Android/iOS belum diverifikasi. Tahap autofill tidak mengubah database Laragon; tahap tujuan pembayaran menambahkan skema sebagaimana dijelaskan berikut. Tidak menjalankan build Android/Gradle atau mengunduh dependensi.

Tahap tujuan pembayaran menerapkan hanya migrasi tambahan `2026_10_11_000007_add_owner_payment_destinations.php` di Laragon lokal. Jumlah baris dan checksum seluruh kolom lama pada tujuh tabel dibandingkan sebelum/sesudah dan tetap sama; tidak reset/seed, menghapus data atau mengubah kredensial. Tidak menambahkan rekening nyata pada database untuk pengujian. PHPUnit tetap memakai SQLite di memori.

Enkripsi rekening adalah perlindungan penyimpanan, bukan pengganti HTTPS/otorisasi. `APP_KEY` harus privat dan dibackup aman; jangan menggantinya sembarangan karena rekening lama bisa tidak dapat didekripsi. Backup konfigurasi usaha yang sudah ada belum mencakup tujuan pembayaran/QRIS: siapkan backup database, file privat dan kunci secara terpisah. QRIS/transfer masih diverifikasi dan dicatat manual, bukan integrasi gateway konfirmasi otomatis.

Tes kembali/refresh mencakup Owner/Kasir, pembayaran penuh/sebagian, pengambilan lunas/sebagian, API gagal, Back/pembatalan modal, pencarian yang dipertahankan, daftar kosong/pendek/error dan respons pagination terlambat. Masuk dari detail transaksi atau rute QR juga tidak menyisakan layar penyelesaian di riwayat Back. Laravel/database tidak diubah pada tahap navigasi ini; verifikasi baru menggunakan repository tiruan, bukan server/perangkat nyata.

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
- [Tujuan pembayaran, bukti detail dan refresh navigasi](docs/TUJUAN_PEMBAYARAN_REFRESH_2026-10-11.md).
- Backend_Needed.md: catatan historis kebutuhan; verifikasi terhadap kode/dokumen terbaru sebelum mengikutinya.

.gitignore diperluas pada kedua repositori untuk varian .env, kunci privat/signing, konfigurasi HTTP privat, cache/log dan backup lokal. Lockfile dependensi, source, migrasi, aset aplikasi dan tes tetap disimpan di Git. Ignore tidak menghapus file yang telanjur tracked.

Aturan ignore backend `api-indafri-laundry` sudah diverifikasi untuk env, vendor, bukti privat/public, log, SQLite dan dump SQL. `.env` nyata tidak tracked di kedua repo; `api_test.http` backend masih tracked dan history lamanya perlu penanganan terkoordinasi. Tidak menghapus data atau mengubah indeks/history Git pada tahap ini.
