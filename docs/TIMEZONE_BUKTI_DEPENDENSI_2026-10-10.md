# Penyelarasan WIB, bukti privat dan upgrade keamanan

Kelanjutan penanganan audit pada 10 Oktober 2026. Menggantikan status terbuka timezone/bukti/dependensi pada catatan audit sebelumnya; temuan lain belum otomatis selesai.

## Waktu laporan

- Laravel tetap menyimpan timestamp UTC (`config/app.php` tidak diubah). Kalender bisnis memakai `Asia/Jakarta`, WIB/UTC+7, melalui `BusinessTime`.
- Tanggal 1 Oktober WIB meliputi 30 September 17:00:00 UTC sampai 1 Oktober 16:59:59 UTC. Query memakai batas UTC, bukan `whereDate` terhadap tanggal UTC.
- Dashboard Owner/Kasir, ringkasan pembayaran khusus Owner, laporan/revenue/CSV, filter transaksi dan pengeluaran memakai batas bisnis yang sama. Nilai pembayaran tetap berdasarkan `paid_at`, bukan tanggal pesanan. Periode dan aturan filter akun yang sudah ada dipertahankan.
- Grafik bulanan 31 hari tetap harian. Bucket grafik tahun dibatasi pada periode kartu; tidak mengambil pembayaran bulan berikutnya.
- JSON timestamp tetap membawa offset UTC. Flutter memformat waktu sebagai WIB, termasuk pembayaran, pengeluaran, detail transaksi dan bon. Periode default menggunakan tanggal WIB meskipun zona perangkat berbeda. CSV mempunyai kolom `timezone` dengan nilai `WIB`, dan `paid_at` adalah waktu WIB.
- Tanggal filter baru dikirim sebagai `YYYY-MM-DD`. Input ISO dari versi Flutter lama tetap diterima dan dipetakan ke tanggal WIB. Pengeluaran baru mengirim UTC eksplisit; input pengeluaran lama tanpa offset dipahami sebagai jam WIB.
- Timestamp lama tidak ditulis ulang, termasuk bukti/histori. Bila catatan lama pernah menyimpan jam WIB sebagai UTC, itu memerlukan pemeriksaan data tersendiri; tidak dikoreksi dengan tebakan pada tahap ini. Atribusi/tanggal pembayaran legacy tetap mengikuti fallback yang sudah ditandai, bukan riwayat pembayaran yang direkayasa.

## Bukti pengambilan

- Upload baru memakai disk lokal privat `proofs`, pada `storage/app/private/proofs-private/`. Tidak diberi public URL atau temporary URL anonim.
- GET `/api/transactions/{id}/proof` memerlukan token, akun aktif, role Owner/Kasir dan transaksi dalam kelompok Owner yang sama. Akses lintas-owner mengembalikan 404. Super Owner tidak diberi akses operasional baru.
- Flutter memuat byte melalui Dio dengan header Bearer, bukan token di URL atau `Image.network` anonim. Detail transaksi menyediakan tombol bukti jika backend mengirim `has_proof_image`. Provider mengikuti sesi dan dilepas setelah tidak digunakan.
- Respons gambar memakai MIME terbatas, `X-Content-Type-Options: nosniff`, serta cache `private, no-store`. Path tersimpan divalidasi; traversal/path arbitrary ditolak.
- Bukti lama pada disk public tetap dipertahankan dan dapat dibaca endpoint setelah pemeriksaan izin. Tidak memindahkan/menghapus file asli maupun memperbarui pointer database lama. Rollback hanya membersihkan file baru pada disk privat.
- Akses statis lama `/storage/proofs/...` diblokir sebelum bypass file statis oleh `public/.htaccess` (Apache), router `server.php` (artisan serve), serta route Laravel sebagai defense in depth. Proses `artisan serve` yang sudah berjalan perlu restart agar memakai router baru.
- Aturan `.htaccess` memerlukan Apache dengan rewrite/AllowOverride yang sesuai. Nginx **tidak membaca .htaccess**; operator hosting harus memasang penolakan sebelum handler file statis. Contoh konfigurasi yang perlu ditinjau operator, bukan dijalankan otomatis:

~~~nginx
location = /storage/proofs { return 403; }
location ^~ /storage/proofs/ { return 403; }
~~~

Pastikan docroot hanya `public/`, directory listing mati, dan tidak ada alias/CDN lain yang mengekspos `storage/app`. Uji URL bukti lama yang benar-benar ada tanpa token, termasuk variasi path/case yang didukung filesystem hosting. Untuk konfigurasi location case-insensitive atau alias tambahan, operator perlu menyesuaikan aturan tersebut. Perlindungan Nginx/Apache produksi belum diuji di hosting nyata.

Validasi upload tetap hanya JPG/JPEG/PNG/WebP maksimal 2 MB. Ini **bukan pemindaian malware**, bukan penghapusan EXIF/re-encoding semua berkas lama, dan bukan jaminan semua konten berbahaya terdeteksi.

## Upgrade terarah

| Paket runtime | Sebelum | Sesudah |
| --- | --- | --- |
| laravel/framework | 13.23.0 | 13.35.0 |
| league/commonmark | 2.8.3 | 2.10.3 |
| league/flysystem | 3.35.2 | 3.36.0 |

Simulasi dilakukan sebelum update. Hanya tiga paket berubah: tidak ada paket ditambah/dihapus atau major upgrade. `composer.lock` dan vendor lokal sudah diperbarui, bukan hanya mengubah batas versi. Composer dijalankan dengan `--with-dependencies --minimal-changes --no-scripts --no-plugins --no-interaction`: tidak menjalankan Artisan, migrasi, seed atau publikasi otomatis. `composer.json` valid dan kebutuhan platform runtime cocok dengan PHP lokal 8.3.30.

`composer audit --locked --no-dev --format=json` setelah update: **0 advisori dan 0 paket abandoned**, sebelumnya 14 advisori pada tiga paket. Hasil ini sesuai basis advisori yang tersedia pada waktu pemeriksaan; tidak membuktikan seluruh aplikasi/deployment aman, dan tidak merupakan audit keamanan plugin native Flutter.

Rujukan primer: [advisori Laravel](https://github.com/laravel/framework/security/advisories/GHSA-jh5r-qr3c-85q8), [CommonMark](https://github.com/thephpleague/commonmark/security/advisories/GHSA-97jj-33gv-5xf9), [Flysystem](https://github.com/thephpleague/flysystem/security/advisories/GHSA-cxf4-7mrp-vvpr), dan [opsi Composer update](https://getcomposer.org/doc/03-cli.md#update-u-upgrade). Tetap matikan debug saat produksi; upgrade tidak menggantikan konfigurasi deployment yang aman.

## Gitignore kedua repo

`git check-ignore --no-index -v` mengonfirmasi frontend mengabaikan env, metadata SDK/build dan signing key; backend mengabaikan env, auth.json, vendor, log, SQLite, backup serta bukti public/privat. Perlindungan dump `.sql` ditambahkan, dengan pengecualian schema-only Laravel yang perlu direview. `.env` nyata tidak tercatat pada hasil `git ls-files` kedua repo.

`api_test.http` backend **masih tracked**, walaupun cocok dengan aturan ignore. Isi kerja sudah berupa placeholder dari tahap sebelumnya; history lama tidak berubah. `.gitignore` bukan pencabutan secret, bukan penghapusan file tracked dan bukan pembersihan riwayat Git. Tidak mengubah Git index, history, token database atau kredensial nyata pada tahap ini.

## Pengujian dan batas

Pengujian memakai SQLite `:memory:`, cache/session array, queue sync, storage fake. Tes regresi baru menolak konfigurasi database lain sebelum migrasi fixture. Flutter menggunakan adapter in-memory, bukan socket ke server nyata.

Kasus yang diuji: pembayaran DP/pelunasan lintas tanggal; batas tengah malam WIB/bulan; kesesuaian summary-detail-CSV; 31 titik grafik bulanan; jumlah grafik tahunan; transaksi hari ini Kasir; filter ISO lama; normalisasi waktu pengeluaran; upload privat; unduh bukti lama/baru; token/role/kelompok Owner; path traversal; router pengembangan sebelum bypass statis; respons byte pada akun nonaktif; dialog bukti tanpa error layout.

Tidak reset database, migrate:fresh/db:wipe, seed akun nyata, memindahkan/menghapus bukti nyata, mengubah kredensial/env/konfigurasi produksi atau menimpa backup. Tidak menjalankan Gradle/clean/build APK. `app_constants.dart` tidak diubah.

Hasil akhir suite dan analisis tersedia di README. Belum diverifikasi: concurrency pada MySQL test terpisah, perangkat fisik/WhatsApp/printer, E2E Flutter ke hosting, server statis/CDN nyata, serta pemetaan timestamp/owner seluruh data lama. Cache finansial yang bertahan melewati pergantian hari tetap termasuk pekerjaan lanjutan.

Selanjutnya: restart backend/aplikasi untuk uji manual, pastikan penolakan URL statis saat deployment, lalu lanjut kontrak Express/pembulatan, controller scanner, cache settings/rollover dan atribusi legacy. Penanganan secret lama di seluruh salinan/history tetap memerlukan koordinasi khusus.
