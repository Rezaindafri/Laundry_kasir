# Audit integrasi dan keamanan KarsaOne

Tanggal: **9–10 Oktober 2026**. Frontend C:\Android\ProjekOM\laundry_app; backend D:\laragon\www\api-indafri-laundry.

## Kesimpulan

**Catatan tindak lanjut 10 Oktober 2026:** dokumen ini mempertahankan hasil audit awal sebelum perbaikan. Kasus backend tambahan kini 13/13 lulus; pengamanan sesi, transaksi, restore, role dan CSV sudah diterapkan pada batch lanjutan. Token/history dan temuan integrasi/deployment belum seluruhnya selesai. Status aktual, perubahan dan batas verifikasi ada pada [penanganan prioritas](PERBAIKAN_PRIORITAS_2026-10-10.md), README dan dokumentasi proyek. Angka/keterangan di bawah merupakan snapshot diagnostik awal, bukan daftar seluruh bug yang masih aktif.

Integrasi Kasir/Owner pada kelompok yang sama terbukti berjalan pada alur utama pengujian. Super Owner sudah dibatasi pada pengelolaan struktur akun. Namun ada **9 pemeriksaan backend tambahan yang gagal**, temuan token dalam Git, ketidaksesuaian Flutter, dan advisori dependensi. Proyek belum layak disebut bebas bug atau siap produksi.

Ini audit/diagnostik, bukan tahap perbaikan semua temuan. Perubahan implementasi bisnis, upgrade paket, pencabutan token dan history rewrite tidak dilakukan.

## 1. Metode, perubahan dan batas keselamatan

Yang dilakukan:

- Menelusuri entry point, router, provider/repository/datasource, endpoint, middleware, scope, controller, model, migrasi, scheduler, native Android/iOS dan tes.
- Memeriksa tracked files dan seluruh revisi Git yang dapat dijangkau, memakai pola secret yang cukup spesifik; hanya nama file temuan yang ditampilkan.
- Menjalankan suite Laravel lama pada SQLite :memory:; menambahkan tes diagnostik dengan token yang diterbitkan endpoint login asli.
- Menambahkan enam tes widget Flutter tanpa jaringan/perangkat; menjalankan suite unit/widget dan analisis Dart.
- Memeriksa advisori runtime menggunakan composer audit --locked --no-dev. Tidak install/update dependensi.
- Memperbarui README.md, DOKUMENTASI_PROYEK_LAUNDRY.md dan .gitignore kedua repo.

Tidak dilakukan: migrasi pada database aplikasi nyata, penghapusan pelanggan/transaksi, reset database, seed akun nyata, perubahan password/key/env, overwrite backup, Git history rewrite, build APK/Gradle clean, atau perubahan produksi. Data kasus uji berada di SQLite di memori. PHPUnit memakai storage/log/cache testing Laravel; bukan bukti penggunaan storage produksi bebas masalah.

Pekerjaan Flutter yang sudah modified sebelum audit dipertahankan. File aplikasi termasuk app_constants.dart tidak saya ubah pada audit ini.

## 2. Hasil pengujian

| Pemeriksaan | Hasil | Arti / keterbatasan |
| --- | --- | --- |
| PHPUnit normal | 50 lulus, 282 assertions | Auth, scope, status/filter, pembayaran, akun, profil, bukti, laporan/export, pengeluaran dan audit |
| BackendSecurityAuditTest.php tambahan | 13 tes; 4 lulus, 9 gagal; 102 assertions | Token asli dan kasus negatif; kegagalan sengaja dipertahankan untuk reproduksi |
| Flutter normal + widget baru | 14 lulus | 8 tes domain/normalisasi + 6 tes UI; repository UI palsu |
| Dart analyze akhir, lib + test | 0 error, 12 warning, 323 info | Tidak bersih; sebagian warning Freezed dan kode lama; tes baru bersih |
| Composer runtime audit | 14 advisori / 3 paket, exit code 1 | Versi lockfile terkena advisori; bukan bukti seluruh celah dapat dieksploitasi melalui fitur aplikasi |
| Pemindaian Git | Token literal di api_test.http backend, termasuk commit awal | Validitas/token pemilik tidak diuji; tidak menampilkan nilai token |

### Matriks alur per role

| Skenario | Bukti | Hasil |
| --- | --- | --- |
| Kasir tambah pelanggan, transaksi harga server, DP | Tes bearer tambahan | Lulus; harga request palsu tidak mengganti harga layanan |
| Pengambilan sebelum siap | Tes bearer + TransactionStatusContractTest | Ditolak 422 |
| Owner melunasi pesanan Kasir, lalu Kasir mengambil tanpa foto | Tes bearer tambahan | Lulus; status collected; ledger 30.000 + 70.000 = 100.000 |
| Laporan saldo vs event, periode pembayaran dan akun pencatat | Suite lama + bearer | Lulus pada fixture; tidak menghitung DP ganda |
| Owner lain membaca transaksi atau menggunakan master/akun kelompok lain | Suite scope + bearer | Ditolak pada kasus yang diuji |
| Kasir mengakses users/reports Owner atau mengganti kredensial sendiri | Suite lama + bearer | Ditolak |
| Kasir nonaktif dan Owner nonaktif | AccountAndFinancialIntegrityTest / scope suite | Akses dibatasi; data monitoring akun nonaktif dipertahankan pada fixture |
| Owner kelola kasir sendiri; Super Owner buat/pindahkan akun | Suite akun/scope | Lulus pada alur yang tersedia |
| Super Owner dashboard struktur; akses transaksi/laporan | Suite lama + bearer | Struktur tersedia; operasional ditolak |
| Pelanggan/layanan dengan riwayat dihapus | OperationalIntegrityGuardTest | Ditolak, data tetap ada pada fixture |
| Upload PHP atau gambar >2 MB | Tes bearer tambahan | Ditolak 422; tidak mengubah pembayaran/ledger |
| SQL injection contoh pada login/pencarian | Tes bearer tambahan | Tidak bypass login/scope |
| Request API tanpa autentikasi/Accept header | Tes tambahan | 401, bukan redirect error |
| Notifikasi username/password salah, nonaktif, error umum | 3 tes widget | Inline notice dan SnackBar muncul, tombol login pulih |
| Modal quick-create: luar modal, Back, simpan | 3 tes widget | Lulus tanpa controller-disposed/overlay assertion; simpan sekali |

Tidak ada klaim sudah menekan seluruh tombol pada tiga akun nyata di HP. Yang benar-benar dijalankan adalah request Laravel/tes UI terisolasi; pemeriksaan alur lainnya berbasis kode.

## 3. Temuan terkonfirmasi: keamanan dan integritas backend

P0 = tangani sebelum repo/deployment publik. P1 = prioritas tinggi. P2 = pengerasan/konsistensi berikutnya. Keyakinan “tinggi” berarti kode atau tes menunjukkan kondisi tersebut, bukan bukti sudah terjadi insiden.

| ID / prioritas | Lokasi / simbol | Bukti dan dampak | Keyakinan | Rekomendasi dan verifikasi |
| --- | --- | --- | --- | --- |
| SEC-01 / P0 | Backend api_test.http, Git commit b06f558 | Literal Bearer terdapat pada file tracked dan commit awal. .env nyata tidak ditemukan tracked. Ignore tidak melindungi secret yang sudah committed. | Tinggi untuk keberadaan; validitas belum diketahui | Cabut token terkait setelah identifikasi aman; ganti contoh dengan variabel privat; sanitasi commit masa depan; rencanakan history cleanup terkoordinasi bila repo dibagikan. Tidak dilakukan tanpa otorisasi. |
| AUTH-01 / P1 | EnsureActiveAccount.php:17–28; AuthController.php:73 | fresh() mengganti model user tanpa token Sanctum aktif. Logout token asli → 500, currentAccessToken() null. Flutter menghapus lokal sehingga tampak berhasil tetapi token server belum dicabut. | Tinggi, tes gagal | Pertahankan konteks token saat refresh user; tes logout token asli → 200 dan token berikutnya → 401. Null-safe delete saja tidak membuktikan pencabutan berhasil. |
| AUTH-02 / P1 | routes/api.php login; tanpa RateLimiter | 25 login gagal berturut-turut tidak menghasilkan 429; tidak ditemukan throttle aplikasi. Proteksi proxy hosting belum diketahui. | Tinggi di aplikasi | Limit per IP + identitas dengan pesan generik; uji 429, cooldown dan akun/IP berbeda. |
| AUTH-03 / P1 | AuthController createToken; config/sanctum.php expiration=null | Token masih diterima setelah waktu uji +31 hari. “Ingat saya” Flutter 30 hari hanya kebijakan lokal. | Tinggi | Tentukan expiry/revokasi server, bersihkan token kedaluwarsa, uji waktu server +31 hari dan penanganan Flutter. |
| AUTH-04 / P1 | AuthController::updatePassword | Password baru disimpan, tetapi token sesi lama tetap dapat GET /profile (200). Endpoint kredensial terkelola mempunyai revokasi; alur password sendiri tidak setara. | Tinggi | Cabut sesi lain sesuai kebijakan, pertahankan atau ganti sesi saat ini secara eksplisit; uji dua token dan hash lama ditolak. |
| DATA-01 / P1 | TransactionController::updateStatus; juga update umum | collected → received diterima 200. Validator melarang membuat collected langsung, tetapi tidak menjaga transisi KELUAR dari collected. Memungkinkan pengambilan/riwayat berulang. | Tinggi, tes gagal | Status terminal tidak dapat dibuka ulang lewat endpoint umum; koreksi formal jika memang dibutuhkan dibahas terpisah. Uji Kasir/Owner, status API/update API dan collect berulang. |
| ERR-01 / P1 | TransactionController catch; UserController catch | Exception marker ikut response pembayaran 500 meski app.debug=false. Rollback pembayaran/audit berhasil pada kasus uji. Raw getMessage dapat membawa detail SQL/path/internal. | Tinggi, tes gagal | Response generik + correlation ID, detail hanya log server terkontrol; uji exception DB/audit/storage tanpa bocor. |
| CSV-01 / P2 | DashboardController::csvValue | Nama =1+1 diekspor apa adanya, berpotensi menjadi formula ketika dibuka spreadsheet. Quoting koma/quote bukan pencegahan formula. | Tinggi, tes gagal | Escape formula pada kolom teks, termasuk whitespace/control prefix dan = + - @; jangan merusak kolom angka; uji Excel/LibreOffice. |
| CFG-01 / P1 | SettingsController::restore | Baris Owner valid telah mengganti nama usaha sebelum baris kasir invalid membuat response 422. Tidak atomik meski endpoint tampak gagal. | Tinggi, tes gagal | Validasi seluruh isi dulu, lalu transaksi DB; uji multi-baris gagal tidak mengubah satu pun setting. |
| ROLE-01 / P1 | UserController::update allowedRoles/owner_id | Super Owner dapat mengubah Owner yang punya kasir+transaksi menjadi Kasir, response 200. Tanggungan tetap menunjuk akun yang kini bukan Owner; akses kelompok lama terganggu. | Tinggi, tes gagal | Blok perubahan role bertanggungan atau sediakan migrasi tanggungan terkontrol dengan persetujuan; jangan pindahkan data diam-diam. |

Pengaturan expiry dan revokasi merupakan tanggung jawab server, bukan sekadar menghapus SharedPreferences. [Dokumentasi Sanctum](https://laravel.com/framework/docs/13.x/sanctum).

## 4. Temuan integrasi dari penelusuran kode

| ID / prioritas | Lokasi | Bukti / ketidaksesuaian | Keyakinan / batas | Rekomendasi |
| --- | --- | --- | --- | --- |
| INT-01 / P1 | Flutter transactions_screen.dart:717,867; TransactionModel::toJson(forRequest); Laravel store | UI Express +25%, request tidak membawa flag/biaya Express, server memakai harga layanan biasa. Lunas sesuai UI dapat melebihi total server → ditolak. | Tinggi statis; tidak diuji tombol Express dengan server nyata | Satu kontrak Express server-side atau nonaktifkan pilihan sampai benar; uji DP/unpaid/full dan deadline. |
| INT-02 / P1 | qr_scanner_screen.dart:156 | MobileScanner(onDetect) tidak diberi controller yang dipakai stop/analyzeImage/dispose. Kamera widget memakai controller berbeda; galeri/lifecycle tidak dikendalikan controller milik screen. | Tinggi statis; kamera nyata belum diuji | Pasang controller yang sama; uji scan sekali, galeri, Back, resume dan navigasi ke transaksi segala status. |
| INT-03 / P1 | config/app.php:68; report provider/_dateParameters | Backend timezone hardcoded UTC; Flutter memilih tanggal kalender perangkat. Hari ini di WIB tidak sama dengan batas hari UTC, khususnya pukul 00–07 WIB. Timestamp parse beberapa model tidak konsisten toLocal. | Tinggi konfigurasi; ketepatan data nyata belum diuji | Tetapkan timezone bisnis dan konversi UTC konsisten tanpa menafsir ulang data lama; uji sekitar tengah malam WIB serta batas bulan. |
| INT-04 / P1 | TransactionController::markPayment/collect/recordPayment | Model/saldo dibaca sebelum DB transaction; tidak ada row lock/idempotency. Request bersamaan berpotensi mencatat delta yang sama dua kali atau balapan dengan sinkronisasi status. | Risiko statis tinggi; kejadian belum dibuktikan pada MySQL concurrency | Re-read dalam lock/transaction dan idempotency; uji request paralel pada DB test MySQL terpisah. |
| INT-05 / P2 | DioClient on401; AuthRepository::getCurrentUser | 401 diubah menjadi UnauthorizedException tanpa mencabut state sesi; auto-login percaya user lokal, tidak memvalidasi /auth/me. Akun/role yang berubah bisa mempunyai UI lama walau server menolak. | Tinggi statis | Sentralisasikan sesi berakhir/403 nonaktif dengan kode API yang stabil; validasi sesi startup dan invalidasi cache sesuai akun. Jangan salah logout pada 401 login. |
| INT-06 / P2 | LaundrySettingsNotifier::save/build | Cache ditulis sebelum remote; build menangkap semua error lalu memakai cache tanpa membedakan unauthorized vs offline. Pengguna bisa melihat perubahan yang tidak berhasil di server. | Tinggi statis | Commit cache setelah sukses server; bedakan offline/forbidden; tes remote gagal dan cache lama dipertahankan. |
| INT-07 / P2 | ownerFinancialProvider keepAlive; dashboard/reports providers | Cache periode tidak otomatis rollover hari atau mendapat push perubahan kasir lain. Angka yang disebut realtime bisa stale sampai refresh. | Tinggi statis | Invalidasi pada mutasi/re-entry/rollover dan tampilkan waktu update; jangan menambah polling berlebihan tanpa pengukuran. |
| HIST-01 / P2 | create_transaction_payments_table backfill; paymentRowsFor; report models | Legacy saldo dijadikan satu event, paid_at memakai updated_at dan recorded_by diisi cashier_id. Source legacy_balance ada, tetapi pembuat bukan bukti penerima pembayaran; UI perlu penandaan. | Tinggi statis | Tampilkan waktu/pencatat lama tidak terverifikasi; jangan mengarang DP atau aktor. |
| HIST-02 / P2 | AuditLogService/Model; AuditLogController | actor_id disimpan, role/nama dibaca dari akun saat ini, bukan snapshot kejadian. Mengganti role/nama bisa mengubah identitas yang ditampilkan dalam riwayat. | Tinggi statis | Snapshot nonrahasia untuk log baru lewat migrasi additive; log lama tetap ditandai sesuai informasi yang tersedia. |
| HIST-03 / P2 | DashboardController::isOwnerCashier; transaksi filter | Setelah kasir pindah, data lama tetap owner_id lama (baik), tetapi filter menggunakan assignment sekarang sehingga filter historis kasir dapat ditolak. | Sedang; desain filter setelah pindah perlu konfirmasi | Pisahkan hak akses kelompok data dengan pilihan aktor historis; uji sebelum/sesudah pindah tanpa membuka data Owner baru. |
| UI-01 / P2 | ios/Runner/Info.plist; printer native service | Camera permission ada; PhotoLibrary usage tidak ada. Printer native menolak non-Android. | Tinggi statis; iOS belum build | Jangan mengklaim printer/galeri setara iOS. Tambahkan izin sesuai kebutuhan dan uji di macOS/perangkat iOS. |
| FIN-01 / P2 | Expense model/migrasi; DashboardController::expenseRowsFor | Hanya occurred_at, tanpa status rencana/dibayar. Tanggal masa depan dalam rentang query sudah dijumlahkan sebagai pengeluaran. Belum ada eksekusi pembayaran terjadwal. | Tinggi struktur; definisi bisnis perlu konfirmasi | Bedakan catatan bertanggal dari rencana yang belum terjadi; jangan menyebut semuanya pembayaran aktual. |
| FIN-02 / P2 | Flutter subtotal round; Laravel harga qty dan summary int | UI membulatkan rupiah, backend decimal lalu ringkasan cast int. Kuantitas pecahan dapat menghasilkan selisih pembulatan dan pembayaran UI melebihi total backend. | Risiko statis; belum diuji UI/API bersama | Tetapkan satu kebijakan pembulatan server-side; uji kuantitas pecahan dan DP/pelunasan. |
| CLEAN-01 / P3 | Dart analyzer; owner_dashboard_screen | 12 warning: 6 invalid_annotation_target Freezed, unused refresh result, unnecessary cast, 3 unreachable defaults, unused painter. 323 info lint/deprecations. Komentar JWT/auto-logout tidak sesuai. | Tinggi dari analyzer | Pembersihan kecil setelah bug prioritas; generated/model annotations ditinjau, bukan hapus fitur massal. |

Deklarasi role master-data masih mencantumkan Super Owner pada sebagian route, tetapi OwnerScopeService menolak operasionalnya. Rapikan deklarasi sesuai izin efektif; jangan memperluas Super Owner ke monitoring.

## 5. Checklist keamanan yang diminta

| Area | Kondisi saat audit | Tindakan / verifikasi berikutnya |
| --- | --- | --- |
| API key / hardcoded secret | Tidak ditemukan API key privat lain dari pola yang dipakai. URL LAN bukan secret. Token api_test.http ditemukan. Mock dan seeder mempunyai password demo yang diketahui. | Jangan mengaktifkan mock/seed privileged demo pada produksi; rotasi token terpapar. Pattern scan tidak menemukan seluruh jenis secret secara pasti. |
| Env / Git | .env nyata tidak tracked; varian ignore diperluas. HTTP publik .env belum diuji. | Docroot hanya public/, akses .env/vendor/storage private ditolak; uji staging tanpa menampilkan isi env. |
| Debug / error | Env lokal debug aktif dan level log debug; response catch tetap bocor walau debug false. | APP_ENV production, APP_DEBUG false dan generic error; pisahkan log privat, retensi/redaksi. Jangan mengubah env lokal diam-diam. |
| Auth server / role admin | Sanctum + active + role + scope digunakan. Kasir/Owner lain/Super operasional ditolak pada kasus uji. Role downgrade belum aman. | Regression token asli untuk setiap endpoint sensitif; perbaiki downgrade/logout. Tidak bergantung frontend atau CORS. |
| Validasi input | Form Laravel validate, batas type/ID/range/pagination ada; harga server diuji. Beberapa teks/alur tidak mempunyai batas ukuran menyeluruh. | Tambahkan limit payload/field sesuai bisnis; validasi authorization sebelum menerima owner_id/service_id. |
| SQL injection | Query Eloquent berparameter; raw sorting CASE ditemukan berupa SQL tetap, bukan input pengguna. Sampel injection tidak bypass. | Audit setiap raw query baru; bind parameter dan whitelist identifier. Tes bukan bukti SQL injection mustahil. |
| Sanitasi / XSS | Flutter merender data sebagai Text, bukan HTML mentah; tidak ditemukan custom HTML/WebView untuk nama/catatan. CSV injection dan advisori rendering framework masih ada. | Encode sesuai konteks HTML/CSV/URL; jangan mengandalkan strip_tags universal. Uji web dan downstream export. |
| DB tidak publik | Env dev menggunakan host loopback; itu tidak membuktikan MySQL bind/firewall publik aman. | Periksa bind-address, firewall, port 3306 dari luar dan hosting network policy. Belum diverifikasi. |
| DB permission | Env dev memakai akun root tanpa password. Ini konfigurasi lokal, tidak bukti akun produksi. | Produksi pakai akun khusus/least privilege; pisahkan akun migrasi bila mungkin. Tidak mengubah user/password DB saat audit. |
| Password hash | Hash::make/check dan hidden password diterapkan; response login tidak mengandung password pada tes. | Pertahankan one-way hash; jangan fitur lihat password asli atau log manager password. |
| Session / token | Secure storage mobile; 30 hari lokal saja. Server token tidak expiry, logout gagal, sesi lain tetap aktif saat password sendiri berubah. | HTTPS, expiry/revokasi server, 401 session cleanup. Keamanan storage web/browser perlu uji tersendiri. |
| Reset password | Reset kredensial terkelola memverifikasi pengelola dan scope, dengan kebijakan panjang password. Tidak ada public forgot-password. | Rate limit/re-auth dan audit; jangan menyebut reset email sudah ada. |
| Batas upload | image + mimes JPG/JPEG/PNG/WebP, max 2048 KB; PHP/oversize ditolak. SVG tidak diizinkan oleh whitelist. | Batas dimensi/pixel, quota, re-encode dan allowlist server; jangan hanya ekstensi. |
| Scan upload | Tidak ditemukan integrasi antivirus/quarantine scanner. | Tentukan threat model; re-encode bukan antivirus. Tambahkan scanning jika diperlukan, gagal aman, jangan mengklaim file bersih hanya karena validator image. |
| Akses bukti | File berada pada disk public/proofs; URL storage dapat dibuka tanpa pemeriksaan owner jika diketahui. Nama acak bukan authorization. | Private storage + download scoped/signed expiry sesuai kebutuhan. Uji akses unauth/lintas owner ke file, bukan hanya transaksi. |
| File transaksi gagal | File dapat tersimpan sebelum transaction berhasil; cleanup orphan tidak terlihat. | Bersihkan file baru jika rollback; uji error setelah upload tanpa menghapus bukti lama. |
| HTTPS / CORS | Flutter LAN memakai HTTP, Android cleartext=true; CORS * dan credentials=false. | Wajib TLS produksi; restrict cleartext sesuai build, origin web sesuai deployment. CORS bukan pengganti auth. |
| Backup / restore | Backup konfigurasi, bukan DB; restore tidak atomik. File backup mengandung kontak/alamat. | Atomic restore + schema limits + akses privat; backup DB terpisah dan pemulihan diuji tanpa overwrite backup asli. |
| Scheduler | Source command/minute/withoutOverlapping ada, suite waktu virtual lulus. | Cron hosting dan timezone/cache-lock aktual perlu verifikasi; tidak dijalankan pada data asli dalam audit. |

Rekomendasi upload berlapis mengikuti [OWASP File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html). Pembatasan tipe/ukuran bukan bukti malware tidak ada.

## 6. Dependensi runtime

Hasil dari lockfile, bukan versi target composer.json. Pemeriksaan --no-dev tidak mencakup advisori paket pengembangan maupun Flutter/native.

| Paket | Versi terkunci | Jumlah / severity | Bukti / catatan |
| --- | --- | --- | --- |
| laravel/framework | v13.23.0 | 1 low | [XSS debug page GHSA-jh5r-qr3c-85q8](https://github.com/advisories/GHSA-jh5r-qr3c-85q8). Debug dev aktif; matikan di produksi, tetap rencanakan patch. |
| league/commonmark | 2.8.3 | 12: 9 high, 3 medium | XSS/DoS parser/extensions. [Contoh DoS GFM table](https://github.com/advisories/GHSA-3q6v-r5mr-hxv8). Tidak ditemukan fitur Markdown input operasional; exploitability aplikasi belum terbukti. |
| league/flysystem | 3.35.2 | 1 low | [Path normalizer UTF-8](https://github.com/advisories/GHSA-cxf4-7mrp-vvpr). Alur upload memakai nama storage yang dibuat framework, namun dependensi tetap perlu patch. |

Tidak menjalankan composer update. Pilih patch aman yang memenuhi Composer, tinjau changelog/lock diff dan ulangi seluruh tes termasuk upload dan audit. Jangan menonaktifkan audit/menyembunyikan advisori untuk mendapat exit code 0.

## 7. Kebijakan .gitignore yang diterapkan

| Repo | Aturan baru |
| --- | --- |
| Flutter | .env.* dengan pengecualian contoh; auth.json; PEM/KEY/P12/PFX/mobileprovision; HTTP private env/local requests; .gradle, log/dump JVM, coverage; folder backups/private dan dump/database lokal |
| Laravel | .env.* dengan pengecualian contoh; private key/signing; HTTP private env/local request; api_test.http; backups/private; database SQLite/WAL lokal dan dump/backup |

Aturan lama build/vendor/node_modules/storage runtime dipertahankan. Source, pubspec.lock/composer.lock, migrasi, logo dan tes tetap versioned. File database fixture yang memang dibutuhkan harus ditinjau sebagai source dan dikecualikan secara spesifik.

Verifikasi aturan ignore: 13 contoh Flutter dan 14 contoh backend lulus, termasuk .env privat di-ignore dan contoh env/source/lockfile/tes/aset tetap tidak di-ignore. Diff check file audit yang diubah lulus. Whitespace yang sudah ada pada app_constants.dart dibiarkan karena bukan perubahan audit ini.

**api_test.http sudah tracked:** git check-ignore --no-index menunjukkan aturan, tetapi Git tetap melacaknya. Audit tidak melakukan git rm --cached, revoke token, rewrite history atau force-push. File/commit lama masih perlu ditangani sebelum repo dibagikan.

## 8. Reproduksi aman dan penanganan temuan

Tes tambahan: tools/audit/BackendSecurityAuditTest.php di repo Flutter, dijalankan dengan PHPUnit backend. Lokasi dipilih agar tes audit tidak diam-diam mengubah suite normal; dapat dipindahkan ke suite backend setelah perbaikan disetujui.

Jalankan hanya dengan APP_ENV testing, DB_CONNECTION sqlite, DB_DATABASE :memory:, DB_URL kosong, cache/session array, queue sync; perintah lengkap ada di README. File tambahan memeriksa env dan konfigurasi efektif sebelum RefreshDatabase. Guard gagal jika cached config bukan DB test.

Tes widget: test/role_workflows_widget_test.dart. Tidak ada HTTP/perangkat nyata. Default suite Flutter tetap lulus.

Urutan yang disarankan:

1. Tangani token committed dan deployment blockers env/HTTPS/DB/seeder.
2. Logout/revokasi dan expiry server; rate limit; sesi Flutter ketika ditolak.
3. State terminal collected, pembayaran idempotent/locking, waktu bisnis konsisten.
4. Guard role downgrade dan restore atomik.
5. Pesan error/CSV, upgrade paket runtime terarah.
6. Express, scanner, legacy attribution dan cache.
7. Jalankan staging/device E2E ketiga role, baru lanjut rilis.

Semua perubahan berikutnya harus kecil, menjaga data/role yang ada dan menggunakan migrasi additive bila diperlukan. Pencabutan token/history cleanup/credential produksi memerlukan otorisasi khusus.

## 9. Hal yang belum berhasil diverifikasi

- UI end-to-end pada akun nyata dan server hosting, termasuk kondisi jaringan putus/pulih.
- Kamera galeri/resume, printer Bluetooth reconnect, WhatsApp/Business, QR bon fisik, keyboard perangkat, launcher/splash setiap OS.
- Build/signing iOS, macOS dan distribusi release Android.
- MySQL concurrency/isolation/DB permissions/firewall/bind serta akses publik env/proof di hosting.
- Cron hosting nyata, file storage permission/retention, backup database dan disaster recovery.
- Pemindaian malware upload, audit vulnerability Flutter/native/dev dependencies, scan full secret entropy/binary/unreachable Git objects.
- Ketepatan tanggal/pencatat data legacy; snapshot role riwayat lama tidak dapat dibuat ulang secara terpercaya.

Tes lulus hanya membuktikan skenario yang dijalankan pada konfigurasi tersebut. Tidak menyatakan aplikasi pasti aman atau seluruh fitur sudah selesai.
