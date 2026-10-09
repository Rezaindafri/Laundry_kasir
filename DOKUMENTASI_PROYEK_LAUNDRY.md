# Dokumentasi Proyek KarsaOne

Pembaruan: **10 Oktober 2026**, berdasarkan kode Flutter/Laravel dan pengujian 9–10 Oktober. Nama file historis dipertahankan agar tautan lama tetap berlaku.

## 1. Produk dan batas cakupan

KarsaOne adalah aplikasi kasir/manajemen operasional. Alur layanan saat ini masih laundry; branding baru tidak mengganti isi database, nama tabel, paket aplikasi atau autentikasi.

Frontend: C:\Android\ProjekOM\laundry_app.
Backend: D:\laragon\www\api-indafri-laundry.

Dokumentasi ini menggantikan keterangan lama “JWT mock”, dashboard dummy, Super Owner memantau semua transaksi, dan pendapatan hanya saldo kumulatif paid_amount. Keterangan itu tidak menggambarkan implementasi sekarang.

Integrasi utama tersedia dan beberapa alur diuji, tetapi **bukan jaminan bebas bug atau siap produksi**. Temuan terbuka ada pada bagian 12 dan laporan audit.

## 2. Arsitektur dan sumber kebenaran

Flutter menggunakan Riverpod, GoRouter, Dio, Material 3, serta pola per fitur data/domain/presentation.

~~~text
lib/
  core/          konfigurasi, tema, router, jaringan, error, util
  shared/        enum role, widget umum
  features/
    auth/        sesi, login, logout, splash
    dashboard/   dashboard tiga role
    master_data/ pelanggan dan layanan
    transactions/ transaksi, pembayaran, pengambilan, scanner
    reports/     laporan dan export
    expenses/    pengeluaran Owner
    audit/       riwayat perubahan
    user_management/ struktur akun
    settings/    profil, usaha, kebijakan sistem, cache perangkat
    printing/    bon ESC/POS dan printer
~~~

main.dart menyiapkan locale Indonesia, SharedPreferences, ProviderScope dan router. AppConstants.useMockApi bernilai false; mock tersedia untuk pengembangan, bukan sumber data operasional saat audit.

Laravel menggunakan PHP ^8.3, framework ^13.8 (lockfile kini 13.35.0), Sanctum ^4.0, Eloquent, validasi request, middleware role/status dan query scope owner. Database aplikasi MySQL; audit menggunakan SQLite di memori.

Harga, estimasi, status resmi, laporan dan audit berasal dari Laravel. Cache Flutter mempercepat tampilan, bukan pengganti otorisasi backend.

## 3. Role dan isolasi kelompok

| Peran | Tanggung jawab | Batas akses |
| --- | --- | --- |
| Kasir / User | Pelanggan/transaksi; pembayaran/pengambilan; dashboard operasional, bon | Kelompok Owner sendiri; tidak mengelola akun atau mengganti username/password sendiri |
| Owner | Operasional kelompoknya, layanan/pelanggan, akun kasir, monitoring, laporan, pengeluaran, riwayat dan informasi usaha | Tidak membaca/mengubah kelompok Owner lain |
| Super Owner | Owner/Kasir, penetapan/pemindahan kasir, aktivasi akun, kebijakan dan konfigurasi sistem | Dashboard struktur akun, bukan transaksi, omzet atau kinerja harian |

users.owner_id mengaitkan kasir ke Owner. Data operasional memakai scope kepemilikan. OwnerScopeService menolak role operasional yang tidak sesuai dan kasir dengan Owner tidak aktif.

Rute operasional memakai auth:sanctum, middleware active/role, dan scoped query. UserController memeriksa kewenangan pengelola. UI bukan mekanisme keamanan utama.

Data historis transaksi tetap memakai transaction.owner_id saat kasir dipindahkan. Filter kasir yang sudah pindah perlu ditinjau karena daftar/validasi filter mengikuti hubungan akun saat ini.

Kelompok database pengujian terisolasi. Audit ini tidak memverifikasi ulang seluruh pemetaan data lama pada database aplikasi nyata.

## 4. Navigasi, branding dan autentikasi

Rute: /splash, /login, /dashboard, /customers, /services, /transactions, /collections, /collection-settlement, /scan-qr, /reports, /users, /audit-logs, /expenses, /settings.

Tab menggunakan shell persisten. Drawer mengikuti role. Logout di Settings. Super Owner mempunyai tab akun, bukan laporan operasional.

Branding: logo lokal assets/brand/karsaone_logo.png, aksen biru, permukaan putih, avatar biru/teks hitam, splash animasi Flutter sekitar 2,6 detik, termasuk saat logout. Aset native launcher/splash tersedia; rendering setiap launcher/perangkat belum diuji.

Login:

1. Flutter mengirim username/password ke POST /api/auth/login.
2. Laravel memeriksa hash password dan status akun.
3. Token Sanctum dikembalikan; token/user disimpan melalui FlutterSecureStorage.
4. Router memilih dashboard dari sesi dan role.
5. Salah kredensial: “Username atau password salah.” Nonaktif: “Akun dinonaktifkan.” Error lain pada alur login dipetakan ke pesan umum.

Sanctum menggunakan bearer token, bukan JWT. Field refresh token lokal tidak menunjukkan adanya endpoint refresh backend.

“Ingat saya” membatasi **30 hari lokal**, saat auto-login. Token baru mempunyai expires_at +30 hari dan Sanctum expiration 43.200 menit juga membatasi token lama. Startup memverifikasi `/auth/me` dan memakai role/owner terkini dari server. Server error tidak memberi akses berdasarkan akun lokal.

Logout sudah diperbaiki dengan mempertahankan konteks bearer pada middleware akun aktif. Token aktif dicabut, sesi lain tidak terhapus. Perubahan password sendiri mencabut sesi lain tetapi mempertahankan sesi saat ini. Login dibatasi 5 request/menit per identitas+IP dan 30/menit per IP; 429 ditampilkan sebagai pemberitahuan aman.

401 API dan 403 khusus akun nonaktif membersihkan sesi Flutter. 403 role biasa dan login gagal tidak mengeluarkan sesi secara keliru; respons token lama tidak membatalkan login baru. Batasan deployment/perangkat dijelaskan pada catatan perbaikan.

## 5. Pelanggan, layanan dan transaksi

Pelanggan:

- Kasir dan Owner dapat menambah.
- Owner memperbarui/menghapus sesuai izin; pelanggan bertransaksi dilindungi dari penghapusan.
- Nama alfabetis; telepon/alamat/jenis kelamin opsional.
- Aksi cepat membuka halaman pelanggan dengan modal tambah.
- Controller input dimiliki State modal, dilepas saat route modal berakhir.
- Tes widget simpan satu kali, tap area luar dan Back lulus tanpa exception. Seluruh kombinasi keyboard/perangkat belum diuji.

Layanan:

- Kasir membaca katalog; Owner mengatur harga, unit dan estimasi.
- Layanan terpakai tidak boleh dihapus.
- Laravel menggunakan harga/estimasi layanan, bukan mempercayai harga/estimasi request Flutter.

Transaksi:

- Query pencarian, status, pembayaran, tanggal, akun dan pagination backend.
- Pencatatan pelanggan, layanan, kuantitas, catatan, metode dan pembayaran awal.
- Invoice/QR mengidentifikasi transaksi. Transaksi baru diarahkan ke detail.
- Update/hapus umum hanya Owner. Pembayaran melalui payment, pengambilan melalui collection.
- Transaksi dibayar/diambil mempunyai perlindungan penghapusan.
- Diskon, refund dan pembatalan finansial bukan alur lengkap saat ini; placeholder bukan implementasi refund.

**Ketidaksesuaian Express:** Flutter menawarkan tambahan 25%, tetapi request tidak mengirim kontrak Express dan Laravel menghitung layanan biasa. Pembayaran penuh sesuai UI dapat ditolak karena melebihi total server. Fitur ini belum terintegrasi.

## 6. Pembayaran dan status resmi

payment_status: unpaid, downPayment, paid.
laundry_status: received, washing, drying, ironing, completed, late, collected.

| Istilah UI | Definisi saat ini |
| --- | --- |
| Diproses | received/washing/drying/ironing; estimasi masih di masa depan |
| Selesai / siap diambil | completed; late juga tetap belum diambil |
| Belum diambil | completed atau late, bukan collected; tidak termasuk semua transaksi baru |
| Terlambat | Belum diambil dan waktu melewati estimasi + durasi sejak dibuat hingga estimasi |
| Sudah diambil | collected melalui pengambilan resmi setelah siap dan pembayaran lunas |

Durasi 2 jam: estimasi jam ke-2; late setelah jam ke-4. Perbandingan memakai >; tepat pada batas belum late. Otomatisasi estimasi adalah aturan aplikasi sekarang, bukan bukti pemeriksaan fisik pekerjaan.

Scheduler laundry:sync-statuses setiap menit dengan withoutOverlapping. Sebagian endpoint juga menyinkronkan kelompok saat request. Tes memakai waktu virtual; cron hosting belum diverifikasi.

Pembayaran:

- “Lunasi Saja” melunasi tanpa mengambil barang; bisa sebelum siap, nonaktif setelah lunas.
- “Ambil & Lunasi” mengambil barang siap dan melunasi sisa; menjadi “Ambil” jika sudah lunas.
- Pengambilan sebelum siap ditolak. Foto opsional.
- File baru disimpan privat; GET `/transactions/{id}/proof` memakai autentikasi, role dan scope Owner. Bukti lama dipertahankan, URL statisnya ditolak melalui aturan server yang perlu diverifikasi pada hosting.
- Boolean multipart harus sesuai validator Laravel; collection dengan 0/1 diuji.

POST /transactions/{id}/payment menerima **paid_amount kumulatif**, bukan nominal tambahan. Backend mencatat selisih positif sebagai TransactionPayment. Saldo 30.000 → 100.000 menghasilkan event 30.000 dan 70.000.

`collected` kini terminal pada update/status umum. Mutasi transaksi dan scheduler membaca ulang baris dengan lockForUpdate dalam DB transaction. Retry saldo kumulatif sama menjadi no-op tanpa ledger/audit tambahan; pembayaran lebih kecil ditolak. Pengambilan memeriksa saldo, bukan hanya label paid. Request paralel MySQL belum diuji; bukan idempotency-key untuk create pesanan. Bukti baru dibersihkan saat rollback tanpa menghapus bukti lama.

## 7. Dashboard Owner, laporan dan pengeluaran

Beranda:

- Ringkasan pembayaran, transaksi, pelanggan, proses dan tagihan.
- Periode/filter ke server; kartu pembayaran/grafik mempunyai endpoint/cache terpisah.
- Kartu operasional merupakan antrean aktif lintas tanggal, berbeda dari periode finansial.
- Filter seluruh kelompok, Me (Owner), kasir termasuk nonaktif.
- Layanan populer, pelanggan dan “Yang Perlu Perhatian” dari Laravel.

Laporan:

- Default **Hari ini**, dengan periode/filter akun.
- Nilai pesanan, pembayaran diterima, sisa tagihan, operasional dan pengeluaran.
- Rincian waktu, transaksi, metode, nominal dan pencatat pembayaran jika tersedia.
- Menu ke Riwayat Perubahan yang sama; tidak ada halaman audit duplikat.
- CSV baris pembayaran sesuai query; kolom teks dilindungi dari formula spreadsheet dan waktu pembayaran diberi penanda WIB.

Kalender bisnis memakai WIB (Asia/Jakarta), penyimpanan timestamp tetap UTC. Batas hari/pekan/bulan/tahun dikonversi ke UTC sebelum query; Flutter memakai tanggal WIB untuk default periode dan menampilkan jam dengan label WIB. Perhitungan pembayaran tetap mengikuti paid_at. Pengeluaran baru membawa offset UTC eksplisit. Data lama tidak ditulis ulang/ditafsir ulang otomatis.

| Angka | Sumber / waktu |
| --- | --- |
| Nilai pesanan | Total transaksi pada rentang tanggal pembuatan |
| Pembayaran diterima | Event berdasarkan paid_at, bukan otomatis tanggal pesanan |
| Tagihan belum lunas | Total-pembayaran transaksi dalam cakupan query, bukan selalu saldo semua umur |
| Filter akun pesanan | Pembuat transaksi, cashier_id |
| Filter akun pembayaran | Pencatat event, recorded_by |
| Pengeluaran | Catatan Expense berdasarkan occurred_at pada periode; bukan saldo kas fisik atau bukti uang sudah keluar |

Owner membayar pesanan kasir: event pada Me, pesanan tetap pembuatnya. Perbedaan angka dua kategori dapat benar.

Data lama:

- Migrasi saldo lama menghasilkan source=legacy_balance dari saldo kumulatif dan timestamp tersedia.
- Waktu pembayaran bertahap asli tidak bisa direkonstruksi dari satu saldo.
- Migrasi mengisi pencatat dengan pembuat transaksi; **bukan bukti penerima pembayaran sebenarnya**.
- Tampilan/CSV perlu menandai keterbatasan; jangan menyajikan atribusi lama sebagai fakta.

Pengeluaran terhubung ke /expenses; ringkasan di Beranda, rincian di Laporan/menu. Tidak ada shift, modal kas, kas fisik, rekonsiliasi atau persetujuan baru.

Waktu pengeluaran dapat dipilih, tetapi belum ada status rencana/dibayar atau job pembayaran terjadwal. Tanggal masa depan dalam rentang laporan tetap dijumlahkan. Definisi pengeluaran aktual vs rencana perlu dipastikan sebelum menganggap fitur ini penjadwalan kas.

Cache keuangan belum otomatis berganti saat tengah malam/tiap perubahan kasir lain. Refresh diperlukan; “realtime” bukan websocket/live push.

## 8. Akun, settings dan riwayat

Owner mengelola kasir sendiri. Super Owner mengelola Owner/Kasir dan hubungan keduanya. Nonaktif tidak menghapus transaksi; monitoring nonaktif diuji tetap menyertakan data.

Kredensial kasir melalui /users/{id}/credentials dengan verifikasi pengelola. Password hash tidak bisa dilihat kembali plaintext. Reset terkelola tersedia; forgot-password publik/email reset belum tersedia.

Settings:

- Profil/password yang diizinkan dikirim ke backend.
- Nama/telepon/alamat usaha per Owner di Laravel.
- Printer/default MAC/ukuran kertas adalah preferensi perangkat, bukan konfigurasi global server.
- Super Owner memakai settings akun/sistem, bukan printer/informasi usaha pribadinya.
- Backup v2 owner_configuration_backup berisi konfigurasi usaha, **bukan** database/akun/password/pelanggan/transaksi.
- Restore hanya Super Owner; seluruh Owner divalidasi sebelum penulisan, Owner duplikat ditolak, dan semua baris berada dalam satu DB transaction. Rollback baris kedua yang gagal diuji.
- Cache usaha Flutter disimpan sebelum remote save; gagal server dapat meninggalkan cache berbeda.

Riwayat:

- Backend mencatat transaksi, pembayaran, pengambilan, update/hapus, akun, pengeluaran, sinkronisasi status.
- Pada alur DB transaction, mutasi dan audit rollback bersama jika gagal.
- Metadata before/after memilih field relevan, tidak password/token.
- Owner membaca kelompok sendiri. Super Owner tidak mendapat monitoring audit operasional.
- Pelaku otomatis null/sistem. actor_id mengacu akun saat dibaca; belum snapshot immutable nama/role saat kejadian.

## 9. Bon, WhatsApp, QR dan platform

Bon ESC/POS atau gambar. WhatsApp aktif jika nomor pelanggan ada. Direct-share Android menggunakan FileProvider cache receipts/, tidak exported, izin URI sementara.

Batas:

- Printer service mendukung Android; platform lain memakai stub/penolakan.
- Direct-share WhatsApp Android; WhatsApp biasa/Business/nomor belum disimpan perlu tes perangkat.
- Scanner ada, tetapi controller stop/analyzeImage tidak dipasang ke MobileScanner; perlu koreksi dan uji lifecycle.
- iOS mempunyai scaffolding/camera permission, tetapi izin photo library belum tertera. Build/signing/printer/galeri/share iOS belum diuji.
- Web tidak membuktikan kesetaraan fitur perangkat Android/iOS.

## 10. Peta endpoint Laravel

Semua path berawalan /api. Izin efektif dari middleware dan controller.

| Fitur | Endpoint | Izin |
| --- | --- | --- |
| Login | POST /auth/login | Publik, throttle identitas+IP dan IP |
| Sesi/profil | POST /auth/logout; GET /auth/me, /profile; PATCH /profile, /profile/password | Login aktif, perubahan sesuai role |
| Pelanggan | /customers resource | Kasir/Owner baca+tambah; Owner update/hapus |
| Layanan | /services resource | Kasir/Owner baca; Owner pengelola |
| Transaksi | /transactions; /transactions/today; /transactions/ready-to-collect | Owner/Kasir, kelompok sendiri |
| Koreksi/hapus | PUT/PATCH/DELETE /transactions/{id} | Owner, aturan riwayat/pembayaran |
| Payment/collection | POST /transactions/{id}/payment, /collection, /proof; PATCH /status | Owner/Kasir, kelompok sendiri |
| Unduh bukti | GET /transactions/{id}/proof | Owner/Kasir aktif, kelompok sendiri; file privat atau legacy terotorisasi |
| Dashboard | GET /dashboard/kasir, /dashboard/owner, /dashboard/owner/financial | Sesuai role operasional |
| Laporan | GET /reports/revenue, /reports/statistics, /reports/overview, /reports/export | Owner |
| Akun | /users; POST /users/{id}/credentials; PATCH /users/{id}/status | Owner/Super Owner sesuai target |
| Struktur | GET /dashboard/super-owner | Super Owner |
| Audit | GET /audit-logs | Owner |
| Pengeluaran | GET/POST /expenses; PUT/PATCH/DELETE /expenses/{id} | Owner |
| Usaha | GET/PATCH /settings | Kasir/Owner baca; Owner ubah |
| Sistem | GET/PATCH /system-settings; GET /account-policy | Super Owner; policy juga Owner |
| Config backup | GET /settings/backup; POST /settings/restore | Super Owner |

Sebagian deklarasi role master data menyebut Super Owner, tetapi OwnerScopeService menolak operasional tersebut. Inkonsistensi deklarasi, bukan izin monitoring penuh.

## 11. Verifikasi dan keselamatan data

Tidak menjalankan migrasi terhadap database aplikasi, reset, seed akun nyata, atau mengubah kredensial/config produksi. PHPUnit menjalankan migrasi fixture pada SQLite :memory: dengan environment testing, DB_URL kosong, cache/session array, queue sync. Upload memakai storage fake.

- Backend normal dan regresi: 78/78 lulus, 529 assertions.
- Audit tambahan: 13/13 lulus, 105 assertions; sebelumnya 9 gagal.
- Flutter: 41 lulus; sesi, notifikasi login/modal, kalender WIB, unduh byte dengan Bearer dan dialog bukti.
- Dart: 0 error, 12 warning lama; pemeriksaan terarah file autentikasi/interceptor/tes perubahan bersih.
- Composer runtime dan seluruh lockfile: 0 advisori setelah upgrade tiga paket; validasi Composer dan persyaratan platform lokal lolos.

Cara testing aman di README. UI test tidak memakai API nyata; API test tidak memakai database pelanggan asli. Tes injection/upload adalah sampel negatif, bukan penetration test lengkap.

## 12. Temuan terbuka dan urutan lanjutan

Sudah ditangani dalam kode: logout/revokasi/expiry/rate limit/sesi Flutter, terminal collected + row lock/retry pembayaran, restore atomik, larangan downgrade Owner bertanggungan, error generik dan formula CSV. Super Owner tetap hanya mengelola struktur akun/sistem.

Yang masih perlu dilakukan:

1. Verifikasi aturan file statis hosting (termasuk Nginx/CDN), serta penolakan URL bukti lama tanpa token. Kode WIB/akses privat/upgrade sudah diuji, bukan bukti hosting sudah terkonfigurasi.
2. Express/pembulatan, controller scanner, cache settings/rollover dan atribusi riwayat legacy.
3. Uji paralel MySQL pada database test terpisah dan E2E perangkat/staging.
4. Tuntaskan penanganan token/history pada seluruh salinan backend dan verifikasi deployment HTTPS/docroot/env/DB permissions/firewall/cron.

[Audit awal](docs/AUDIT_INTEGRASI_KEAMANAN_2026-10-10.md) dan [tahap pertama](docs/PERBAIKAN_PRIORITAS_2026-10-10.md) adalah snapshot historis. [WIB, bukti dan upgrade](docs/TIMEZONE_BUKTI_DEPENDENSI_2026-10-10.md) memuat kelanjutan terbaru dan batas deployment.

## 13. Git dan deployment

.gitignore kedua repo mencakup env varian, kunci privat/signing, konfigurasi HTTP privat, cache/log dan backup/data lokal. Source, lockfile, migrasi, contoh env tanpa rahasia, aset dan tes tidak dihapus.

api_test.http backend masih tracked tetapi isi kerja sekarang memakai placeholder; fingerprint token terpapar diblokir Sanctum. Riwayat awal tetap mengandung token. Tidak menghapus baris token nyata, mengubah indeks, rewrite history atau rotasi kredensial. Semua salinan backend harus menerima mitigasi; koordinasikan history cleanup sebelum repo dibagikan.

Produksi: .env privat di luar docroot, debug mati, HTTPS, akun DB khusus/izin minimum, DB tidak terbuka ke internet, scheduler aktif, penyimpanan bukti berizin. Audit kode tidak membuktikan kondisi hosting.

Informasi usaha, backup dan bukti mengandung data pelanggan: batasi akses, retensi dan salinan. Backup konfigurasi bukan strategi backup database.
