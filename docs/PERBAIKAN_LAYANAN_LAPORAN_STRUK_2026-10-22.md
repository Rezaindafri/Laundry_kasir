# Layanan, request gagal, Laporan, dan struk — 22 Oktober 2026

## Cakupan perubahan

Tahap ini mengubah **Flutter/frontend**. Laravel ditelusuri pada `routes/api.php` dan `DashboardController::overview`; kontrak `/reports/overview` tetap menggunakan `start_date`, `end_date`, dan `cashier_id`, dengan scope/validasi Owner yang sudah ada. Angka dan rincian tidak dihitung ulang secara lokal. Tidak ada perubahan kode Laravel, migrasi, reset database, perubahan kredensial, konfigurasi produksi, atau pemasangan dependensi.

| Bagian | Sebelum | Sesudah |
| --- | --- | --- |
| Batal membuat layanan | Form kosong langsung ditutup; konfirmasi hanya untuk perubahan isian | Layanan baru selalu dikonfirmasi, termasuk form kosong, tombol Batal, tap luar dan Back. Form edit yang tidak berubah tetap dapat ditutup biasa |
| Simpan layanan gagal | Modal sudah ditutup sebelum API menyimpan | Modal menunggu hasil API; gagal tampil di dalam form dan isian tetap ada. Double tap dan Back selama penyimpanan tidak menggandakan request |
| Kegagalan API | Penanganan tersebar; upload belum mempunyai send timeout eksplisit | Timeout koneksi/kirim/terima, notifikasi terpusat untuk jaringan/5xx, deduplikasi notifikasi, dan pelepasan listener. Kegagalan membaca secure storage menolak request, bukan membiarkannya menggantung atau mengirim tanpa autentikasi |
| Deskripsi fitur | Beberapa paragraf/petunjuk panjang | Keterangan statis utama Owner/Kasir diringkas menjadi 2–4 kata. Konfirmasi, validasi, detail data dan peringatan keamanan tetap informatif. Super Owner dan deskripsi Laporan tidak dirombak |
| Filter Laporan | Seluruh halaman diganti indikator loading setiap pilihan | Kontrol filter tetap terlihat; cache hit langsung mengganti hasil server. Filter belum siap hanya memuat area hasil, tanpa menampilkan angka pilihan sebelumnya |
| Struk cetak/gambar | QR di tengah, identitas terpisah, padding/jeda besar | QR kiri, nama/nomor pelanggan kanan, invoice di bawah, lalu waktu, layanan/estimasi dan rincian pembayaran. Data transaksi yang berguna dipertahankan |
| Kertas struk | `feed(3)` + `cut()` yang menyisipkan lima baris kosong | Reset printer di awal, tanpa feed awal tambahan, dua baris pengaman akhir dan perintah potong tanpa lima baris tersembunyi |

## Cache Laporan dan konsistensi

- Respons Laravel disimpan hanya dalam memori, bukan persistensi lintas akun. Tidak ada data contoh di alur produksi.
- Prefetch menyiapkan Hari ini, 7 hari, Bulan ini dan kombinasi akun (Me/Kasir termasuk nonaktif dari respons backend), maksimal 12 akun per putaran. Dua worker spekulatif membatasi koneksi paralel; cache dibatasi 48 hasil.
- Akun di atas batas prefetch, rentang tanggal kustom baru, atau pilihan yang belum selesai dipersiapkan tetap memerlukan request pertama. Tidak mungkin menyiapkan semua rentang tanggal tak terbatas secara instan. Setelah berhasil dimuat, hasilnya dapat dipakai ulang selama masih berlaku.
- Batas umur cache dua menit diperiksa saat pilihan berikutnya. Pergantian tanggal WIB, refresh manual/kunjungan ulang halaman, pergantian sesi dan disposal membatalkan generasi cache lama. Ini bukan websocket/polling otomatis tiap dua menit.
- Respons awal yang lambat, respons filter sebelumnya, dan respons akun lama tidak boleh mengganti hasil terbaru. Request baca yang sudah dikirim mungkin masih diselesaikan jaringan; hasil kedaluwarsa diabaikan.
- Kegagalan prefetch menghentikan sisa antrean spekulatif, tidak mengganti laporan aktif, dan tidak memicu spam notifikasi/log error debug. Pilihan aktif yang gagal mempunyai status gagal dan tombol Coba lagi.
- CSV tetap meminta ekspor Laravel dengan periode/akun terpilih. Respons laporan yang bukan struktur laporan valid ditolak, bukan dianggap nominal nol. Pesan internal server 5xx tidak diteruskan sebagai rincian laporan.

## Request gagal bukan bukti rollback

Koneksi terputus tidak otomatis berarti memory corruption. Masalah yang dapat ditangani di sini adalah exception, request menggantung, respons kedaluwarsa, isian hilang, dan penyimpanan ganda.

Request penyimpanan tidak diulang otomatis oleh mekanisme baru. Server mungkin sudah melakukan commit sebelum respons terputus; notifikasi meminta pengguna memeriksa data terbaru sebelum mencoba kembali. Timeout frontend **tidak membatalkan/menjamin rollback Laravel**. Idempotensi/atomicity pembayaran yang sudah ada tidak diubah. Crash native/driver atau semua kemungkinan kerusakan memori tidak dapat dijamin hilang oleh penanganan jaringan ini.

## Struk

- Header thermal dibuat sebagai raster hitam-putih dengan QR dan identitas berdampingan. Bagian lain tetap teks ESC/POS agar payload tidak menjadi screenshot seluruh struk.
- QR tetap berisi invoice yang sama, memakai ukuran modul bulat dalam dot printer serta margin putih empat modul agar tidak buram akibat scaling. Lebar diuji pada 384 dot/58 mm dan 576 dot/80 mm.
- Total pesanan, pembayaran masuk, sisa tagihan, status dan estimasi tiap layanan tetap ada; caption WhatsApp tahap sebelumnya tidak diubah.
- Margin fisik kepala cetak/pemotong dan firmware tidak bisa dihapus oleh layout. Dua baris akhir adalah kompromi penghematan dan keamanan pemotongan; perlu tes printer nyata sebelum menguranginya lagi.
- Pratinjau gambar sintetis dapat dibuat dengan `flutter test --no-pub --dart-define=RECEIPT_PREVIEW_PATH=build/receipt-preview.png --dart-define=RECEIPT_PREVIEW_FONT=C:/Windows/Fonts/consola.ttf test/receipt_layout_test.dart`. Parameter font hanya untuk preview pengujian, bukan path runtime aplikasi. Hasil preview tahap ini diperiksa secara visual; tidak memuat data pelanggan nyata.

## Verifikasi dan batasan

Regresi baru meliputi pembatalan layanan kosong/berisi, kegagalan simpan tanpa kehilangan draft, double tap/Back saat menyimpan, cache hit, pergantian filter cepat, pemuatan awal lambat, pergantian akun, kedaluwarsa/WIB, kontrak query API, respons tidak valid, timeout tanpa retry write, deduplikasi notifikasi, layout QR/identitas dan byte cetak 58/80 mm.

Seluruh suite Flutter: **199 tes lulus**, termasuk 30 regresi baru. Analisis Dart: **0 error, 11 warning lama** pada model auth/dashboard Owner; lint gaya masih ada. Pratinjau struk sintetis sudah dirender dan diperiksa secara visual.

Tes menggunakan repository/adapter sintetis, tanpa API hosting, database nyata, kamera, WhatsApp atau printer fisik. Tidak menjalankan build APK/Gradle atau mengunduh paket. APK yang sudah ada tidak diperbarui oleh perubahan source ini; perlu build release baru untuk pengujian perangkat.

Tes manual lanjutan: putus koneksi saat memuat/menyimpan, coba filter belum di-cache dan rentang kustom, verifikasi data terbaru sesudah pembayaran, cetak berulang pada printer 58/80 mm, pindai QR hasil cetak, lalu kirim foto struk melalui WhatsApp.
