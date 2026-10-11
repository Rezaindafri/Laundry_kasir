# Perbaikan navigasi Back — 11 Oktober 2026

## Aturan dan perubahan

- Popup, dialog, pencarian dan drawer ditutup sebelum halaman di bawahnya.
- Tab mempertahankan riwayat dengan push, bukan pushReplacement/go. Back kembali satu halaman, termasuk halaman asal scanner. Masuk langsung tanpa riwayat diarahkan ke Beranda lebih dahulu; konfirmasi keluar hanya di Beranda tanpa riwayat.
- Rute yang sudah login memakai satu ShellRoute. Ini menghilangkan assertion Page key/shell ganda yang direproduksi saat scanner membuka tab lain. Navigation bar hanya tampil di tab utama; scanner/pengambilan/layanan/audit/pengeluaran tetap halaman sementara.
- Form pelanggan inline, layanan, profil/password, kebijakan akun dan manajemen akun tidak lagi membuang controller saat widget sheet masih menjalankan animasi penutup. Helper menunggu `ModalRoute.completed`; bukan delay arbitrer. Sheet kredensial baru dibuka setelah sheet akun benar-benar dilepas.
- Aksi cepat pelanggan tidak melakukan go() setelah penutupan form. Penutupan tetap menampilkan daftar pelanggan dan Back berikutnya kembali ke asal.
- Request penulisan menggunakan counter pengunci navigasi, yang dilepas dalam finally. Selama menyimpan transaksi, pembayaran, pengambilan, pelanggan, layanan, akun, pengeluaran atau settings, editing/perpindahan tab dinonaktifkan dan Back menampilkan pesan tunggu. Popup input yang dibatalkan tidak mengirim request simpan.
- Halaman yang sudah tertutup/tertutupi tidak melanjutkan submit atau membuka popup berikutnya setelah animasi selesai.
- Scanner memakai controller yang sama untuk preview, galeri dan stop. Route observer/app lifecycle menghentikan kamera ketika tertutupi/background dan melanjutkan saat kembali. Hasil lookup QR setelah Back diabaikan. QR tetap membuka pengambilan/pembayaran untuk transaksi yang ditemukan, termasuk masih diproses atau sudah diambil; aturan pembayaran/kesiapan tetap berasal dari backend.

Implementasi utama: `core/widgets/safe_modal_sheet.dart`, `core/widgets/navigation_write_guard.dart`, `core/router/app_router.dart`, `dashboard_shell.dart`, `qr_scanner_screen.dart`, serta pemanggil form yang bersangkutan.

## Verifikasi

- Seluruh Flutter unit/widget: **97 lulus**, `flutter test --no-pub --concurrency=1 --reporter expanded`.
- `navigation_back_widget_test.dart`: **29 uji** lifecycle controller selama animasi, tap luar/Back/submit, riwayat tab ketiga role, drawer, direct entry, detail imperatif, aksi cepat pelanggan, kunci simpan, transaksi sukses/gagal, Bayar Saja/pengambilan, lookup terlambat, penggantian scanner, pause/resume kamera dan form layanan/profil/password/akun/kredensial.
- Analisis terarah 13 file kode/tes: **0 error, 0 warning**, 343 lint/hint informasi gaya/deprecation. `git diff --check` lulus (Git menampilkan peringatan normalisasi LF/CRLF).
- Repository/kamera pada tes menggunakan fixture; tidak ada socket, Bluetooth, kamera atau database aplikasi nyata. Log 401/403 di suite keamanan merupakan respons negatif tiruan yang diharapkan.

## Batas dan langkah berikutnya

Laravel, database, migrasi, kredensial dan `app_constants.dart` tidak diubah pada tahap ini. Request penulisan tetap lewat repository/endpoint Laravel yang sudah ada. Tidak menjalankan build Android/Gradle, pub get, cleanup cache atau penghapusan file/data. Tes tetap dapat memperbarui cache pengujian Flutter yang biasa.

Belum diuji di HP Android nyata, iOS atau server staging: hardware/predictive Back, perilaku keyboard tiap perangkat, izin kamera, resource Surface native dan simpan melalui jaringan nyata. Hasil unit/widget tidak membuktikan seluruh kombinasi perangkat/server aman.

Langkah berikutnya: restart aplikasi penuh (perubahan struktur router jangan hanya hot reload), lalu uji aksi cepat pelanggan → Back/tap luar/simpan; tab → scanner → Back; drawer → Back; dan Bayar Saja/pengambilan → Back ketika jaringan lambat. Pastikan tidak ada pengiriman ganda dan hasil pembayaran di server tetap sesuai. Tidak perlu flutter clean atau menghapus cache untuk mencoba perubahan ini.
