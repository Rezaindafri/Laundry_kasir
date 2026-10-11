# Multi-layanan, pembayaran dan pengambilan bertahap

Implementasi Flutter dan Laravel, 10 Oktober 2026. Data operasional tetap dibatasi per Owner; Kasir mengakses kelompoknya sendiri. Tidak menambahkan monitoring operasional Super Owner.

## Aturan yang dipakai

- Satu transaksi/QR/bon mempunyai beberapa baris layanan. Masing-masing menyimpan nama/unit/harga, jumlah, subtotal termasuk Express, estimasi selesai dan status pengambilan sendiri.
- Form Transaksi Baru menggunakan satu bagian Layanan dengan satu kartu awal. Tambah layanan menyisipkan kartu kosong dengan tampilan yang sama, bukan membuka alur layanan kedua yang terpisah. Pemilihan, jumlah/unit dan estimasi berada dalam masing-masing kartu; Express tetap setelah seluruh daftar. Kartu pertama juga boleh dihapus jika masih ada kartu lain, tetapi kartu terakhir tidak dapat dihapus.
- Semua layanan baru mulai dari waktu pencatatan transaksi yang sama. Estimasi gabungan adalah **waktu selesai paling akhir**, bukan penjumlahan durasi. Contoh: Cuci 2 jam + Setrika 2 hari, estimasi transaksi 2 hari; estimasi 2 jam tetap ditampilkan di samping Cuci. Penjadwalan berurutan/ketergantungan pekerjaan belum diterapkan.
- Durasi layanan boleh 0, kosong atau null, dinormalisasi menjadi 0. Artinya **tanpa proses: langsung siap**, bukan estimasi belum diketahui. Barang tanpa estimasi tidak otomatis terlambat.
- Status resmi ditentukan Laravel. Baris selesai saat mencapai estimasi, terlambat setelah melewati dua kali durasi sejak transaksi dibuat, dan collected setelah pengambilan resmi.
- Transaksi ditutup hanya setelah seluruh baris diambil dan seluruh tagihan lunas. Status transaksi menjadi late jika ada sisa baris terlambat, completed jika semua sisa siap, selain itu proses.
- Transaksi campuran dapat masuk antrean Diproses dan Belum Diambil sekaligus karena baris berbeda. Ringkasan/filter menghitung transaksi, tidak menggandakan nominal karena banyak baris.
- Pengambilan sebagian berarti memilih **seluruh kuantitas satu baris**, belum sebagian kuantitas pada baris yang sama.
- Bayar Saja mencatat nominal tambahan, metode dan catatan opsional, tanpa mengambil barang. Nominal tidak boleh negatif/nol atau melebihi sisa tagihan. Setelah lunas, aksi pembayaran nonaktif.
- Bayar & Ambil mencatat pengambilan baris siap dan pembayaran tambahannya dalam satu transaksi database. Foto tetap opsional, disimpan privat per pengambilan. Tarik halaman pengambilan untuk memperbarui kesiapan dari server.

## DP tidak dibayar dua kali

Kebutuhan saldo pembayaran adalah nilai kumulatif baris yang sudah diambil ditambah baris yang dipilih. DP yang sudah masuk menjadi kredit. Pengambilan terakhir wajib mencukupi total tagihan, termasuk selisih biaya transaksi lama.

Contoh total Rp80.000: layanan A Rp30.000 (2 jam), B Rp50.000 (4 jam), DP awal Rp20.000.

| Kejadian | Uang masuk baru | Saldo pembayaran | Pengambilan |
| --- | ---: | ---: | --- |
| Buat transaksi | Rp20.000 | Rp20.000 / DP | Belum ada |
| Jam ke-2: ambil A | Rp10.000 | Rp30.000 / DP | Hanya A |
| Bayar Saja berikutnya | Rp50.000 | Rp80.000 / lunas | B tetap belum diambil |
| B siap, ambil B | Rp0 | Rp80.000 / lunas | Semua diambil |

Ledger menerima tiga event, total Rp80.000. Waktu/metode/pencatat/catatan masing-masing event dipakai laporan; tidak mengikuti ulang tanggal pesanan. Foto A, waktu dan pelakunya tidak ditimpa saat B diambil.

## Kontrak API

Path berikut berawalan `/api`, memerlukan Bearer token akun aktif serta izin kelompok Owner.

### Membuat transaksi

`POST /transactions`: `customer_id`, `services` (1–50 baris), pembayaran awal/metode/catatan sesuai kontrak yang sudah ada.

Setiap baris `services` berisi `service_id`, `qty`, `price` (field kompatibilitas; Laravel tetap memakai harga katalog), dan `express` boolean opsional. Express dihitung +25% per baris di server, dibulatkan ke rupiah untuk transaksi baru. Estimasi diambil dari layanan, tidak dari client. Unit hari dari Flutter dikonversi ke jam saat menyimpan layanan.

Respons memuat semua `transaction_details`, termasuk `service_name`, `service_unit`, `timing_configured`, `estimated_finish_at`, `late_at`, `express_fee`, `laundry_status`, `is_ready`, `is_collected`, `collected_at`, `collected_by` dan `has_proof_image`. Path file privat tidak dikirim. Estimasi gabungan nullable jika semua barang tanpa proses.

### Bayar Saja

`POST /transactions/{id}/payment`:

```json
{
  "amount": 10000,
  "payment_method": "cash",
  "payment_note": "DP tambahan",
  "request_id": "95c5a0e3-8d1f-43c5-a1d4-578be0863c47"
}
```

`amount` adalah uang yang diterima **sekarang**. `request_id` UUID wajib untuk nominal tambahan. Retry payload yang sama dengan UUID sama tidak menambah pembayaran/audit; UUID sama dengan isi berbeda ditolak. Flutter mempertahankan UUID untuk retry pembayaran yang gagal dengan nominal/metode/catatan sama.

Kontrak lama `paid_amount` kumulatif tetap diterima untuk konsumen lama. Jangan mengirim `amount` dan `paid_amount` bersama. Retry saldo kumulatif sama menjadi no-op. Metode tersedia: cash, qris, transfer.

### Pengambilan

`POST /transactions/{id}/collection`, multipart:

```text
detail_ids[] = ID baris siap pertama
detail_ids[] = ID baris siap berikutnya
payment_amount = nominal tambahan (boleh 0 bila DP/lunas mencukupi)
payment_method = cash / qris / transfer
payment_note = opsional, maksimum 1000 karakter
settle_payment = 0
proof_image = opsional
```

ID harus milik transaksi tersebut, belum diambil dan siap. Laravel memeriksa ulang dengan row lock, bukan mempercayai checkbox client. Sisa pembayaran, baris pengambilan dan audit berubah atomik; kegagalan tidak mencatat uang/pengambilan berhasil. Pengulangan ID baris yang sudah diambil ditolak, tidak menambah ledger.

Untuk kompatibilitas, tanpa `detail_ids` berarti seluruh sisa baris. `settle_payment=1` tanpa `payment_amount` melunasi seluruh sisa. Flutter baru mengirim array multipart `detail_ids[]` dan nominal tambahan eksplisit. Endpoint `/proof` lama tetap full-handover setelah semua sisa siap dan lunas, tidak menimpa metadata baris yang sudah diambil.

`GET /transactions/{id}/proof?detail_id={lineId}` mengunduh bukti baris melalui autentikasi/scope Owner. Tanpa `detail_id` menggunakan bukti tingkat transaksi untuk kompatibilitas. Upload tetap mengikuti validasi gambar/ukuran yang sudah ada.

### Filter dan laporan

`GET /transactions?ready_for_collection=1` mengambil transaksi yang mempunyai baris siap belum diambil. `active_processing=1` mengambil transaksi dengan baris masih diproses. Dashboard memakai query scope yang sama.

Rincian pembayaran dan CSV menambahkan `payment_note`. Laporan tetap menggunakan event pembayaran berdasarkan `paid_at`/kalender WIB, bukan menjumlah ulang pembayaran dari setiap layanan. Audit yang sama menyimpan before/after detail layanan serta pengambilan sebagian; tidak membuat riwayat baru atau menyimpan rahasia.

## Migrasi dan data lama

Migrasi backend: `database/migrations/2026_10_10_000006_add_service_line_handover_and_payment_notes.php`.

- Menambah metadata layanan/pengambilan serta catatan/UUID pembayaran; tidak mengganti atau menghapus tabel lama.
- Menyalin deadline transaksi lama ke detail, bukan menghitung dari konfigurasi durasi layanan yang mungkin sudah berubah. Nilai transaksi/harga/kuantitas/saldo pembayaran dipertahankan.
- Nama/unit yang sebelumnya tidak mempunyai snapshot hanya dapat memakai katalog yang tersedia saat migrasi; bukan rekonstruksi nama katalog historis.
- Status sudah diambil dipertahankan, tetapi waktu/pelaku pengambilan lama yang tidak tersedia tetap null. UI menyatakan informasi tidak tersedia, tidak mengarang pelaku/waktu.
- Estimasi historis kosong tidak diartikan otomatis sebagai barang tanpa proses; `timing_configured` membedakan estimasi tidak tersedia dari layanan baru berdurasi 0.
- Sudah diterapkan **maju** pada Laragon. Jumlah/checksum kolom asli yang diperiksa sebelum/sesudah identik: 4 transaksi, 4 detail, 3 pembayaran, 8 pelanggan, 5 layanan. Verifier read-only ada di `tools/audit/multi_service_migration_snapshot.php`.
- Jangan menjalankan rollback migrasi ini di database aplikasi: rollback membuang kolom metadata baru. Tidak melakukan reset, seed akun, penghapusan data, perubahan kredensial atau konfigurasi produksi.

Saat deployment ke database lain, tinjau migrasi, siapkan backup terpisah dan jalankan migrasi maju setelah persetujuan. Uji migrasi dengan salinan data, bukan reset database aplikasi.

## Verifikasi dan batasan

- Laravel: **87 tes / 621 assertions** lulus pada SQLite di memori; **13 tes keamanan / 105 assertions** juga lulus. Mencakup DP/pelunasan/pengambilan bertahap, ketepatan ledger, retry UUID, larangan mengambil sebelum siap, penolakan lintas-Owner, bukti privat dan migrasi legacy.
- Flutter: **57 tes** lulus, termasuk 12 tes multi-layanan dan 4 tes formulir layanan terpadu; request/model, Bayar Saja, pilihan pengambilan, modal/layout, receipt image dan pembentukan byte ESC/POS diuji tanpa menghubungkan printer. Tes formulir memastikan tambah/hapus kartu, nilai baris lain tetap utuh, jumlah desimal/Express/DP benar, estimasi 0 dipertahankan dan validasi baris di luar layar tetap berlaku.
- Analisis Dart: 0 error, 12 warning lama. Diff diperiksa untuk whitespace.
- Schema migrasi Laragon/MySQL sudah diverifikasi. Request paralel MySQL, Flutter → Laravel end-to-end pada HP, kamera, cetak Bluetooth, pengiriman WhatsApp dan build iOS belum diverifikasi pada tahap ini.
- Tidak mengubah `app_constants.dart`, memasang dependensi, menjalankan Gradle/build Android atau membersihkan cache besar. Perubahan file konstanta yang sudah ada dipertahankan.
- Temuan audit lama yang tidak terkait tetap tercatat di README/dokumentasi; hasil tes bukan jaminan bebas bug atau siap produksi.

Langkah berikutnya: coba pada HP dengan transaksi dua layanan berdurasi berbeda, DP awal, pembayaran tambahan, pengambilan pertama/kedua dan kedua jenis bon. Pastikan laporan Owner kelompok yang sama menampilkan uang masuk pada waktu pembayaran dan Owner lain tetap tidak mempunyai akses.
