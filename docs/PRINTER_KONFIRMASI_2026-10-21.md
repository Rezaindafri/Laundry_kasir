# Printer Bluetooth dan konfirmasi pembatalan

Perubahan frontend Flutter, 21 Oktober 2026. Tidak mengubah Laravel, database, kredensial atau konfigurasi produksi. Perubahan pengguna pada AndroidManifest.xml dan app_constants.dart dipertahankan.

## Akar masalah dan perbaikan

- Pilihan printer sebelumnya hanya mengubah state form, lalu baru tersimpan ketika tombol Simpan ditekan. Sekarang pemilihan menyimpan nama/MAC printer segera di SharedPreferences perangkat. Draft nama usaha/alamat/telepon tidak ikut disimpan atau dikirim ke server.
- Preferensi printer/kertas adalah milik instalasi perangkat, sedangkan konfigurasi usaha tetap scoped Owner. Setelah app/provider dibuat ulang, printer terakhir dipilih kembali untuk cetak. Koneksi Bluetooth dibuat saat mencetak; tidak dipertahankan sebagai koneksi background permanen.
- Respons refresh settings server yang terlambat mengambil ulang preferensi perangkat terbaru agar tidak menimpa printer yang baru dipilih.
- Plugin print_bluetooth_thermal memanggil cancelDiscovery() saat connect. Android 12+ memerlukan BLUETOOTH_SCAN untuk pemanggilan ini, meskipun daftar perangkat hanya memakai paired/bonded devices. Sebelumnya kode hanya meminta CONNECT. Sekarang kedua izin diverifikasi saat memilih printer dan sebelum cetak; request izin bersamaan memakai satu future, pesan penolakan izin tetap jelas.
- Tidak menambahkan izin lokasi, active Bluetooth discovery, atau mengubah nama/package aplikasi. Permission SCAN sudah ada di manifest; yang diperbaiki adalah permintaan izin runtime. Log capabilities.length is already loaded bukan bukti kegagalan koneksi.
- Daftar printer sebelumnya Column tanpa scroll. Sekarang tinggi sheet dibatasi dan daftar dapat di-scroll, termasuk layar kecil dan banyak perangkat tertaut.

Referensi Android: [izin Bluetooth](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions), [cancelDiscovery](https://developer.android.com/reference/android/bluetooth/BluetoothAdapter#cancelDiscovery()).

## Konfirmasi tindakan

Dialog hapus pelanggan/layanan/transaksi/pengeluaran yang sudah ada dipertahankan tanpa dialog ganda. Penghapusan baris layanan dari draft bon serta perubahan aktif/nonaktif akun atau penonaktifan tujuan pembayaran meminta konfirmasi sebelum mutasi.

Form pelanggan/layanan/transaksi/pembayaran/pengeluaran/akun/kredensial/profil/password/tujuan pembayaran meminta konfirmasi bila draft diubah lalu dibatalkan melalui Back atau area luar modal. Pilihan Lanjut mengisi mempertahankan input. Form kosong dan pemilih/filter biasa tetap dapat ditutup normal; halaman biasa tidak mendapat dialog setiap Back. Form guarded menonaktifkan drag-dismiss agar swipe tidak melewati pemeriksaan draft.

Hasil simpan yang valid menutup form tanpa dialog pembatalan. Controller baru dibuang setelah animasi overlay selesai. Saat request penyimpanan berlangsung, guard navigasi lama tetap berlaku: pengguna diminta menunggu, bukan ditawari membatalkan pembayaran yang mungkin sedang diproses Laravel.

Cakupan konfirmasi bukan guard global untuk setiap perpindahan tab. Draft konfigurasi usaha di halaman Settings utama belum diberi mekanisme konfirmasi lintas-tab; tidak merombak routing/root navigator pada tahap ini.

## Pengujian dan batas

Tes memakai plugin MethodChannel, SharedPreferences dan repository tiruan; tidak mencetak kertas atau menghubungi server/database asli. Tes printer meliputi izin CONNECT+SCAN, penolakan izin, retry, pemeriksaan sebelum cetak, penyimpanan/recreate provider dan race refresh. Tes widget memakai pemilih 30 perangkat pada layar 360 × 480, serta konfirmasi batal/hapus dan lifecycle overlay.

Hasil akhir: seluruh 163 tes Flutter lulus. Analisis `lib` dan `test`: 0 error, 11 warning lama pada model auth/dashboard Owner, 1077 lint/hint informasi. Perubahan tidak menyelesaikan seluruh lint proyek. Indikator loading kini berhenti setelah daftar printer tersedia, bukan terus beranimasi selama pengguna memilih printer.

Belum diverifikasi: printer fisik, prompt izin OEM Android, koneksi saat printer terhubung ke aplikasi/perangkat lain, dan hasil bon fisik. Tidak menjalankan Gradle, clean, instalasi dependensi atau upgrade paket.

Langkah manual berikutnya: rebuild/jalankan versi baru, izinkan Perangkat di sekitar di Android, pilih printer sekali, tutup/buka aplikasi, lalu cetak dua bon berurutan. Ulangi setelah printer dimatikan/dinyalakan dan ketika izin ditolak untuk memastikan pesan serta retry sesuai. Jangan uninstall/hapus data aplikasi hanya untuk memperbaiki pilihan printer karena tindakan itu menghapus preferensi lokal.
