# Penanganan prioritas audit KarsaOne

Tanggal: 10 Oktober 2026. Ini hasil implementasi setelah [audit awal](AUDIT_INTEGRASI_KEAMANAN_2026-10-10.md), bukan pengganti bukti diagnostik sebelum perbaikan.

Catatan ini adalah **snapshot tahap pertama**. Kelanjutan WIB/UTC, disk bukti privat dan upgrade tiga dependensi sudah dikerjakan dan diuji pada [catatan tahap kedua](TIMEZONE_BUKTI_DEPENDENSI_2026-10-10.md). Angka tes dan status terbuka di bawah menjelaskan keadaan sebelum tahap kedua; hasil terbaru ada pada README.

## Yang sudah diubah

| Temuan | Perubahan dan verifikasi | Status / batas |
| --- | --- | --- |
| SEC-01: token dalam Git | `api_test.http` diganti placeholder. Sanctum menolak fingerprint SHA-256 token yang terpapar melalui `config/auth_security.php`. Tes callback fingerprint asli dan request dengan fingerprint sintetis diblokir. | Mitigasi kode; tidak menghapus token dari DB atau riwayat Git. Backend lain/copy lama belum otomatis terlindungi. |
| AUTH-01: logout 500 | Middleware mempertahankan konteks token ketika memuat ulang akun. Logout mencabut token bearer aktif; token kedua tetap dapat digunakan. | Lulus API dengan token login asli pada DB pengujian. |
| AUTH-02: login tanpa limit | 5 request/menit per identitas + IP dan 30 request/menit per IP. HTTP 429 mempunyai pesan aman dan Retry-After. | Lulus limit identitas, pergantian username dan cooldown. Cache limiter lintas-instance/proxy hosting belum diuji. |
| AUTH-03: expiry server | Token baru diberi expires_at +30 hari; Sanctum expiration 43.200 menit juga membatasi token lama tanpa expires_at. | Lulus penolakan setelah 31 hari. Tidak menjalankan prune token terhadap DB nyata. |
| AUTH-04: sesi lain setelah ganti password | Perubahan password sendiri mencabut sesi lain secara atomik, mempertahankan token saat ini. Password salah tidak mencabut sesi atau mencatat sukses. | Lulus API. Tidak mengganti password akun nyata saat pengerjaan. |
| INT-05: sesi Flutter | Startup memverifikasi `/auth/me`, memperbarui role/owner dari server. 401 dan 403 akun nonaktif membersihkan sesi; 403 izin biasa dan kegagalan login tidak memicu logout salah. Event memakai identitas token request sehingga respons lama tidak membatalkan login baru. | Lulus tes repository/provider/interceptor tanpa socket. E2E perangkat ke Laravel belum dijalankan. |
| DATA-01: membuka ulang pengambilan | `collected` terminal pada update umum/status; pengambilan tetap hanya sesudah siap dan saldo lunas. Label `paid` yang bertentangan dengan saldo tidak bisa bypass. | Lulus Kasir/Owner; tidak membuat alur pembukaan ulang/refund baru. |
| INT-04: pembayaran balapan | Update/status/payment/collection/proof/delete memuat ulang baris melalui lockForUpdate dalam DB transaction. Scheduler juga mengunci dan membaca ulang. Retry saldo kumulatif sama tidak menambah pembayaran/audit; nilai lebih kecil ditolak. | Lulus DP 30.000 → 100.000, retry, ledger/audit, scheduler dengan model lama. Request paralel MySQL **belum diuji**; bukan implementasi idempotency-key untuk pembuatan pesanan. |
| CFG-01: restore sebagian | Validasi seluruh owner dan owner duplikat sebelum penulisan, lalu seluruh restore dalam DB transaction. | Lulus input invalid tanpa mutasi, restore valid, serta rollback baris pertama ketika penulisan baris kedua gagal. Tidak me-restore backup nyata. |
| ROLE-01: downgrade Owner | Owner dengan anggota, transaksi/master/config/audit, pembayaran atau pengeluaran tidak dapat diturunkan menjadi Kasir. Owner kosong tetap dapat diubah sesuai kewenangan Super Owner. Guard riwayat hapus akun turut mencakup pencatat pembayaran/pengeluaran. | Lulus; tidak memindahkan kelompok atau data existing secara otomatis. Super Owner tidak mendapat monitoring operasional. |
| ERR-01: exception bocor | Catch transaksi/akun mengembalikan pesan generik + error_id; detail hanya report/log server. Validasi/otorisasi tetap 4xx, bukan disamarkan menjadi 500. Log Dio hanya metadata pada debug build, bukan body/token. | Lulus exception dan Throwable, rollback pembayaran, serta larangan detail internal dalam respons. APP_DEBUG produksi dan proteksi log masih perlu deployment verification. |
| CSV-01: formula | Kolom teks dengan prefix `=`, `+`, `-`, `@`, termasuk spasi/control ASCII, diawali apostrof. Quote/newline di-escape; nominal tetap angka. | Lulus export API beberapa prefix; Excel/LibreOffice nyata belum diuji. |
| File baru saat rollback | Bukti baru dibersihkan jika collection/proof gagal; bukti lama tidak dihapus. | Lulus simulasi audit gagal setelah upload. Disk bukti masih public: otorisasi download belum diperbaiki. |

Kontrak pembayaran tetap **saldo kumulatif**. Retry saldo sama merupakan no-op, termasuk tidak mengganti metode pembayaran yang sudah tercatat. Koreksi metode pembayaran historis bukan fitur baru dalam tahap ini.

Rujukan mekanisme server: [Sanctum](https://laravel.com/framework/docs/13.x/sanctum), [rate limiting](https://laravel.com/framework/docs/13.x/rate-limiting). Kebijakan 30 hari dan batas request adalah pilihan proyek, bukan kewajiban bawaan Laravel.

## Hasil pengujian

- PHPUnit normal: **71/71 lulus, 452 assertions**. Termasuk 21 tes regresi keamanan/integritas baru.
- Kasus audit terpisah: **13/13 lulus, 105 assertions**, sebelumnya 4 lulus/9 gagal.
- Flutter: **31/31 lulus**, tanpa jaringan/printer/kamera/database nyata.
- Analisis Dart seluruh lib/test: **0 error, 12 warning lama**. Pemeriksaan terarah file autentikasi/interceptor/tes yang diubah bersih setelah lint dirapikan; lint/info lama di fitur lain tetap ada.
- Syntax PHP: 14 file perubahan lolos `php -l`; diff check backend lolos.
- Scan pola secret berkeyakinan tinggi pada tracked working tree backend: tidak menemukan token Bearer literal/kunci privat/AWS key dari pola yang digunakan. Riwayat Git lama tetap mempunyai temuan; scan ini tidak membuktikan tidak ada secret jenis lain.
- Composer audit tidak dijalankan ulang/di-upgrade pada tahap ini; 14 advisori runtime hasil audit sebelumnya masih belum ditangani.

PHPUnit memakai SQLite `:memory:`, CACHE_STORE/SESSION_DRIVER array, QUEUE_CONNECTION sync dan DB_URL kosong. Tes baru memeriksa konfigurasi efektif sebelum RefreshDatabase. Pengujian API menjalankan Laravel, bukan hanya widget/pesan Flutter palsu.

## Keselamatan dan penerapan

Tidak ada reset database, penghapusan transaksi/pelanggan nyata, migrasi ke database aplikasi, seed/reset akun, perubahan kredensial/env/konfigurasi produksi, overwrite backup, rewrite history atau force-push. Tidak install/update dependensi atau membangun ulang APK/Gradle pada tahap ini. File kerja Flutter yang sudah modified dipertahankan; app_constants.dart tidak diedit pada penanganan ini.

Database/schema tidak berubah: tidak ada migrasi baru yang perlu dijalankan untuk batch ini. Restart/reload aplikasi/backend saat mencoba kode terbaru. Jika backend memakai config cache pada deployment, cache harus dibangun ulang melalui prosedur deployment; perubahan config tidak berlaku pada proses yang masih memuat versi lama. Config cache backend lokal tidak ditemukan saat diperiksa. Sesi lama berumur >30 hari kini perlu login ulang; data bisnisnya tidak dihapus.

Penghapusan token nyata, rotasi akun/key, atau pembersihan history harus dilakukan terkoordinasi setelah persetujuan khusus. Jangan mempublikasikan history lama dengan menganggap .gitignore sudah menghapus isinya.

## Urutan lanjutan yang belum selesai

1. Selaraskan batas hari/periode WIB dan timestamp UTC tanpa menafsir ulang data lama; uji transaksi/pembayaran sekitar tengah malam dan batas bulan. Ini bagian prioritas integritas laporan yang masih tertunda.
2. Lindungi download bukti dengan izin kelompok dan mekanisme file privat, serta upgrade paket runtime terarah sambil menjalankan regresi. Jangan memindahkan/menghapus bukti existing tanpa rencana kompatibilitas.
3. Benahi kontrak Express + pembulatan harga, controller scanner, cache settings setelah sukses server, rollover cache dan penandaan atribusi legacy. Aturan pengeluaran rencana vs aktual perlu keputusan bisnis.
4. Uji request paralel pada **database MySQL pengujian terpisah**, lalu E2E tiga role pada staging/perangkat: kamera, galeri, printer, WhatsApp, jaringan putus/pulih, expiry/logout dan isolasi Owner.
5. Tutup deployment blockers: penanganan history/token pada seluruh salinan backend, HTTPS/docroot, debug/log privat, DB user/permission/firewall, scheduler hosting, backup/pemulihan teruji. Jangan mengubah kredensial atau konfigurasi produksi tanpa persetujuan.

Lulus suite ini bukan bukti seluruh aplikasi aman, seluruh fitur selesai, atau hosting sudah siap produksi.
