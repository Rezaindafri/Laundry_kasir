# Tujuan pembayaran, bukti detail dan refresh navigasi

Implementasi 11 Oktober 2026, Flutter dan Laravel.

## Alur dan kontrak

1. Owner membuka Setting → Tujuan pembayaran. Tambahkan QRIS (nama + gambar) atau rekening transfer (nama tujuan, bank, pemilik, nomor rekening). Beberapa rekening dan QRIS didukung. Tujuan dapat diubah/nonaktifkan, tidak dihapus.
2. Transaksi Baru, Bayar Saja dan Bayar & Ambil menawarkan tujuan aktif sesuai metode. QRIS memuat gambar melalui API berizin; transfer menampilkan bank/pemilik/nomor lengkap serta salin nomor. Tunai tidak memuat tujuan.
3. Flutter mengirim `payment_destination_id` pada create pesanan dengan pembayaran awal, payment tambahan, atau multipart collection dengan pembayaran. Laravel memeriksa owner/kind/active secara server-side. Metode yang sudah memiliki tujuan aktif mewajibkan pilihan; data lama tanpa konfigurasi tetap kompatibel.
4. Ledger menyimpan ID dan snapshot label, bukan rekening plaintext. UUID retry pembayaran tambahan mempertahankan payload/tujuan yang sama, termasuk bila tujuan sesudahnya dinonaktifkan. Bila pilihan lama tidak tersedia, Flutter tidak diam-diam menggantinya dengan rekening lain: periksa riwayat sebelum mencatat pembayaran baru.
5. Detail Transaksi membaca endpoint detail, menampilkan Riwayat pembayaran dan Bukti pengambilan dengan foto opsional/per layanan yang dapat diperbesar. Foto yang sudah tersedia adalah bukti penyerahan barang, bukan bukti transfer. Informasi historis yang tidak tersedia diberi keterangan, tidak dibuat-buat.

QRIS/transfer adalah tujuan untuk pembayaran yang dicatat manual. Ini bukan gateway/webhook: aplikasi tidak otomatis memastikan uang masuk bank/QRIS.

## Keamanan dan kompatibilitas data

- Nomor rekening dienkripsi menggunakan encrypted cast Laravel; key tetap di server, tidak dibundel ke Flutter atau preferences.
- Scope Owner/Kasir dan role diperiksa di endpoint; Super Owner tidak mendapat monitoring atau konfigurasi operasional tambahan.
- QRIS privat, tidak menerima SVG; JPG/JPEG/PNG/WebP maksimal 2 MB dan 2048 × 2048. Gambar diunduh melalui Dio ber-token, bukan URL publik/token di URL.
- Audit mencatat perubahan tujuan tanpa nomor rekening/path rahasia. Logger Dio tidak menulis body/token.
- `APP_KEY` wajib privat dan dibackup aman. Penggantian key tanpa rencana dekripsi/migrasi dapat membuat rekening lama tidak dapat dibaca. Enkripsi database tidak melindungi transport HTTP: hosting tetap harus HTTPS.
- Backup konfigurasi usaha yang tersedia belum mencakup tujuan pembayaran/QRIS. Backup server harus mencakup database, file privat dan key yang dilindungi. Penggantian gambar tidak menghapus file lama; kebijakan retensi perlu ditentukan terpisah.
- Migrasi maju 000007 menambah tabel/kolom nullable ledger. Diterapkan lokal dengan perbandingan tujuh tabel lama sebelum/sesudah: jumlah baris/nilai tetap identik. Tidak reset database, seed akun, menghapus data, mengganti kredensial atau config produksi.

## Refresh navigasi

Refresh hanya read model/data: Beranda sesuai role, transaksi/Pengambilan, pelanggan/layanan, laporan, akun, pengeluaran, profil/settings, riwayat audit dan detail transaksi. Filter, pencarian, draft dan pilihan layanan dipertahankan. Form Transaksi Baru memperbarui katalog tanpa menghapus input.

RouteObserver memantau PageRoute, bukan dialog/sheet. Halaman baru memuat data awal; cached page disegarkan saat dibuka/kembali. Callback tidak merekonstruksi router/auth/form, tidak melakukan polling atau retry berulang, serta melewati penyimpanan yang masih berjalan. Daftar Pengambilan tetap memakai reload setelah mutasi berhasil dan menghindari request balik yang ganda.

Ini bukan websocket atau otomatisasi tengah malam; perubahan perangkat lain terlihat saat refresh/kunjungan berikutnya.

## Verifikasi

- PHPUnit penuh: 95 tes, 707 assertions; SQLite `:memory:`/storage fake. Delapan tes tujuan pembayaran: 86 assertions.
- Flutter penuh: 138 tes; tidak menghubungi API/database asli. Request payload diuji melalui HttpClientAdapter di memori.
- Dart lib/test: 0 error, 11 warning lama, 1016 info lint/hint.
- Tidak menjalankan Gradle/build Android, clean atau unduhan dependensi. Pengujian tidak memasukkan nomor rekening/QRIS nyata ke database Laragon.

Masih perlu uji perangkat/staging: tambah dua rekening dan QRIS milik usaha, verifikasi gambar dapat dipindai di layar HP, lakukan DP/pelunasan/pengambilan pada database staging, cek foto/catat pembayaran di Detail, coba Back/tab saat offline dan saat keyboard terbuka. Login kelompok Owner lain harus tidak dapat membaca/menggunakan tujuan tersebut. Kondisi hosting HTTPS, file storage dan backup key belum diverifikasi oleh unit test.
