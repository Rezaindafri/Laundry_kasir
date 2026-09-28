# Backend Needed - Laundry Management System

Dokumen ini merangkum status real backend Laravel untuk aplikasi laundry, termasuk bagian yang sudah selesai, bagian yang masih perlu diselesaikan, serta kontrak backend yang masih perlu dibuat final agar aplikasi siap ke tahap production.

Tanggal revisi: 14 September 2026.

## 1. Ringkasan Status

### Sudah menggunakan API dan sudah berjalan

- Login, logout, dan pengambilan session user melalui Sanctum.
- Validasi akun aktif/non-aktif untuk login sudah diterapkan dan tervalidasi.
- CRUD pelanggan.
- CRUD layanan laundry.
- CRUD transaksi.
- Update status pembayaran dan status pengambilan melalui endpoint transaksi.
- Parsing transaksi dengan relasi customer dan detail layanan.
- Dashboard owner dan kasir sudah terhubung ke backend real.
- Summary pendapatan owner sekarang dihitung dari `paid_amount` di backend, bukan dari data dummy atau logika frontend.
- Payment contract untuk `paid_amount` dan `payment_status` sudah diperbaiki dan divalidasi.
- Data transaksi lama yang sudah lunas tapi belum konsisten sudah diperbaiki melalui migration repair.
- Profil pengguna backend sudah berjalan: melihat profil, memperbarui profil, dan mengganti password.
- Upload bukti pengambilan sudah berjalan dan menyimpan file ke storage server.
- Export laporan CSV sudah berjalan untuk laporan pendapatan dengan filter tanggal.
- Endpoint status akuntansi untuk transaksi sudah dibakukan pada `downPayment` dan `late`.

### Sudah diimplementasikan pada revisi hari ini

- login aktif/non-aktif fix di database dan controller
- kontrak status transaksi finalisasi `payment_status`/`laundry_status`
- profil user backend `GET/PATCH /api/profile` dan `/api/profile/password`
- upload bukti pengambilan `POST /api/transactions/{id}/proof`
- export laporan `GET /api/reports/export?type=csv`
- test Laravel untuk fitur utama item di atas sudah lulus

### Yang masih bisa ditingkatkan nanti

- pagination dan filter server-side untuk laporan besar
- PDF export yang lebih formal dan layout laporan profesional
- audit log perubahan akun dan transaksi
- upload avatar foto profil yang lebih lengkap
- hardening keamanan dan role policy yang lebih luas untuk produksi

## 2. Prioritas Pengerjaan

| Prioritas | Area | Status saat ini | Dampak |
|---|---|---|---|
| P0 | Konsistensi status transaksi dan pembayaran | Sudah final dan tervalidasi | Transaksi dan dashboard sudah memakai satu kontrak status yang konsisten |
| P0 | User management dan account owner | Sudah ada dan login aktif/non-aktif sudah berfungsi | Akses admin dan account state sudah lebih aman dan stabil |
| P1 | Profil pengguna/settings | Sudah diimplementasikan di backend | User bisa melihat & memperbarui profil serta ganti password |
| P1 | Dashboard dan laporan server-side | Sudah ada untuk owner/kasir utama, perlu filter/pagination untuk skala lebih besar | Data besar masih bisa dioptimasi, tetapi feature utama sudah berfungsi |
| P1 | Bukti pengambilan | Sudah diimplementasikan ke storage server | Bukti pengambilan dapat disimpan dan diaudit dari server |
| P2 | Export PDF/Excel | CSV export sudah tersedia; PDF/Excel formal masih dapat ditingkatkan | Laporan dasar sudah bisa diunduh, namun export format lanjutan masih open |
| P2 | Audit log dan keamanan operasional | Masih bisa ditambahkan untuk production hardening | Keamanan operasional belum sepenuhnya terdokumentasi lengkap |

## 3. Fokus Tahap Berikutnya: Akun Owner

### 3.1 Kebutuhan data user

Backend perlu menyediakan field user yang konsisten:

- `id`
- `name`
- `username`
- `role`
- `is_active`
- `avatar_url` atau `avatar_path` jika avatar digunakan
- `created_at`
- `updated_at`

Role minimal:

- `super_owner`
- `owner`
- `kasir`

Validasi role harus dilakukan di backend, bukan hanya dengan menyembunyikan menu frontend.

### 3.2 Endpoint yang diperlukan

Semua endpoint berikut harus memakai `auth:sanctum` dan policy/permission berbasis role.

```text
GET    /api/users
POST   /api/users
GET    /api/users/{id}
PUT    /api/users/{id}
PATCH  /api/users/{id}/status
DELETE /api/users/{id}
PUT    /api/profile
POST   /api/profile/avatar       (opsional)
PUT    /api/profile/password
```

### 3.3 Aturan akses akun

- Super Owner dapat membuat, mengubah, menonaktifkan, dan menghapus akun sesuai kebijakan sistem.
- Owner dapat mengelola akun kasir dan melihat akun yang berada di bawah kewenangannya.
- Kasir tidak dapat mengakses manajemen user.
- Akun yang `is_active = false` tidak boleh login.
- User tidak boleh menghapus atau menonaktifkan akun dirinya sendiri tanpa alur khusus.
- Username harus unik.
- Perubahan role harus divalidasi server.
- Password tidak pernah dikembalikan dalam response API.
- Response login harus mengembalikan field user yang dibutuhkan frontend tanpa tambalan dummy.

### 3.4 Response yang disarankan

```json
{
  "data": {
    "id": 2,
    "name": "Siti Aminah",
    "username": "owner",
    "role": "owner",
    "is_active": true,
    "avatar_url": null,
    "created_at": "2026-09-05T08:00:00.000000Z",
    "updated_at": "2026-09-05T08:00:00.000000Z"
  }
}
```

### 3.5 Validasi endpoint user

- `name`: wajib, string, panjang wajar.
- `username`: wajib, unik, tidak boleh mengandung karakter terlarang.
- `role`: hanya enum role yang dikenal.
- `password`: wajib saat membuat user baru, opsional saat update.
- `is_active`: boolean.
- Semua error validasi memakai format response yang konsisten agar dapat dipetakan ke `Failure` di Flutter.

## 4. Konsistensi Transaksi

### 4.1 Kontrak status

Frontend memiliki status laundry:

- `received`
- `washing`
- `drying`
- `ironing`
- `completed`
- `collected`
- `late`

`late` sebaiknya tidak disimpan sebagai status permanen jika status tersebut merupakan hasil perhitungan waktu. Backend dapat menyimpan status proses dasar dan mengembalikan status efektif berdasarkan `estimated_finish_at`.

Backend perlu menetapkan kontrak final:

- nama field: `order_status` atau `laundry_status`, jangan berganti-ganti
- nilai enum yang valid
- apakah status otomatis dihitung server atau frontend
- siapa yang boleh mengubah status
- transisi status yang valid

Contoh transisi yang disarankan:

```text
received -> washing -> drying -> ironing -> completed -> collected
```

Transisi `collected` hanya melalui proses pengambilan yang terotorisasi.

### 4.2 Pembayaran

Frontend mendukung:

- `unpaid`
- `downPayment`
- `paid`

Backend saat ini didokumentasikan hanya mendukung `unpaid` dan `paid`. Backend perlu menambahkan keputusan eksplisit:

1. mendukung `down_payment` sebagai status resmi, atau
2. menyimpan `paid_amount` dan menghitung status pembayaran dari nominal.

Field yang disarankan:

- `payment_status`
- `payment_method`
- `total_amount`
- `paid_amount`
- `remaining_amount` sebagai nilai hasil perhitungan
- `paid_at`
- `paid_by`

Operasi pelunasan harus atomik: update status transaksi, nominal pembayaran, user pelaksana, dan waktu pembayaran dalam satu transaksi database.

### 4.3 Endpoint transaksi tambahan yang disarankan

Endpoint CRUD yang ada tetap dipertahankan, tetapi operasi bisnis sebaiknya memiliki endpoint khusus:

```text
POST /api/transactions/{id}/collect
POST /api/transactions/{id}/settle
POST /api/transactions/{id}/collection
GET  /api/transactions/{id}
GET  /api/transactions/{id}/history
```

Payload collection yang disarankan:

```json
{
  "settle_payment": true,
  "paid_amount": 35000,
  "proof": "multipart file optional"
}
```

Server harus memastikan transaksi belum berstatus `collected` sebelum operasi dilakukan agar tidak terjadi pengambilan ganda.

## 5. Bukti Pengambilan

Saat ini bukti foto bersifat opsional dan hanya disimpan lokal pada perangkat. Untuk backend production diperlukan:

```text
POST /api/transactions/{id}/collection-proof
GET  /api/transactions/{id}/collection-proof
DELETE /api/transactions/{id}/collection-proof
```

Kebutuhan:

- upload multipart image
- validasi MIME type dan ukuran file
- kompresi atau resize server-side bila diperlukan
- penyimpanan path/file URL
- `uploaded_by`
- `uploaded_at`
- relasi ke transaksi
- penghapusan atau penggantian bukti dengan policy yang jelas

Karena bukti bersifat optional, transaksi tetap dapat dikoleksi tanpa file.

## 6. Dashboard dan Laporan

### 6.1 Masalah saat ini

Dashboard Owner/Super Owner masih menampilkan angka statis. Laporan menghitung pendapatan dan statistik dari transaksi yang sedang dimuat di frontend. Cara ini tidak aman untuk data besar dan dapat menghasilkan angka yang tidak lengkap.

### 6.2 Endpoint dashboard

```text
GET /api/dashboard/summary
GET /api/dashboard/queue
GET /api/dashboard/ready-for-collection
```

Parameter yang disarankan:

- `date`
- `from`
- `to`
- `branch_id` jika nanti mendukung cabang

Data summary minimal:

- pendapatan hari ini
- pendapatan bulan berjalan
- jumlah transaksi
- total pelanggan
- laundry diproses
- laundry sudah selesai
- belum diambil
- siap diambil
- layanan terlaris

`ready-for-collection` harus memakai aturan server yang sama dengan frontend: transaksi belum collected dan `estimated_finish_at <= now`.

### 6.3 Endpoint laporan

```text
GET /api/reports/summary
GET /api/reports/revenue
GET /api/reports/services
GET /api/reports/transactions
```

Laporan harus mendukung filter tanggal dan pagination. Perhitungan pendapatan harus menjelaskan apakah berdasarkan transaksi dibuat, nominal dibayar, atau transaksi selesai.

### 6.4 Export laporan

Frontend sudah memiliki endpoint path untuk export PDF/Excel, tetapi tombol masih menampilkan pesan placeholder. Backend perlu menyediakan:

```text
GET /api/reports/export/pdf
GET /api/reports/export/excel
```

Kebutuhan:

- filter tanggal yang sama dengan halaman laporan
- role authorization owner/super owner
- response file dengan content type benar
- nama file yang aman dan informatif
- batas ukuran dan timeout export

## 7. Profil Pengguna dan Settings

Frontend settings saat ini menyimpan data di `SharedPreferences`. Field tampilan sekarang menggunakan `Nama pengguna`, nomor telepon, alamat, ukuran kertas, dan printer default.

### 7.1 Profil pengguna

```text
GET  /api/profile
PUT  /api/profile
PUT  /api/profile/password
POST /api/profile/avatar       (opsional)
```

Data yang disimpan server:

- nama pengguna
- username
- nomor telepon
- alamat jika memang merupakan data profil user
- avatar

### 7.2 Pengaturan printer

Printer Bluetooth dan ukuran kertas adalah konfigurasi perangkat, sehingga tetap boleh local-only. Jika ingin sinkron antar perangkat, siapkan:

```text
GET /api/user-settings
PUT /api/user-settings
```

Jangan menyimpan kredensial printer atau secret device secara terbuka di backend.

## 8. History Pelanggan

Frontend saat ini memuat seluruh transaksi lalu memfilter berdasarkan `customerId`. Untuk skala production, sediakan endpoint khusus:

```text
GET /api/customers/{id}/transactions
```

Kebutuhan:

- pagination
- sorting terbaru ke terlama
- filter status pengambilan
- filter tanggal
- total transaksi atau summary pelanggan
- authorization agar user hanya dapat melihat data sesuai role

Response minimal perlu memuat:

- invoice
- created_at
- service name
- total
- payment status
- order/laundry status
- collected_at jika tersedia

## 9. Search, Filter, dan Pagination

Saat ini filter dan sorting dilakukan di memory frontend. Backend perlu mendukung query agar tidak seluruh transaksi diunduh:

```text
GET /api/transactions?search=&statuses[]=&payment_status=&from=&to=&page=
```

Parameter yang disarankan:

- `search`
- `order_status[]`
- `payment_status[]`
- `customer_id`
- `from`
- `to`
- `sort`
- `direction`
- `page`
- `per_page`

Backend harus mengembalikan metadata pagination:

```json
{
  "data": [],
  "meta": {
    "current_page": 1,
    "last_page": 4,
    "per_page": 20,
    "total": 73
  }
}
```

Aturan default sorting aplikasi tetap:

1. transaksi belum diambil lebih dahulu
2. transaksi sudah diambil di bagian bawah
3. masing-masing kelompok terbaru ke terlama

## 10. Audit Log

Sebelum production, perubahan penting perlu dicatat:

- login dan logout
- pembuatan, perubahan, dan penghapusan user
- perubahan role atau status aktif user
- pembuatan transaksi
- perubahan status laundry
- pembayaran dan pelunasan
- pengambilan laundry
- upload atau penghapusan bukti pengambilan

Endpoint opsional untuk owner/super owner:

```text
GET /api/audit-logs
```

Data log minimal:

- actor user
- action
- entity type
- entity id
- before value
- after value
- IP/device metadata jika diperlukan
- timestamp

## 11. Keamanan Backend

- Semua endpoint bisnis memakai Sanctum.
- Gunakan Laravel Policies/Gates atau permission table, bukan hanya pemeriksaan role di UI.
- Validasi ownership dan akses data pada setiap request.
- Gunakan database transaction saat membuat atau mengubah transaksi dan pembayaran.
- Tambahkan rate limit untuk login dan endpoint sensitif.
- Jangan mengembalikan password, token internal, atau data sensitif.
- Validasi upload file secara ketat.
- Gunakan pagination untuk daftar transaksi, pelanggan, dan user.
- Simpan waktu dalam timezone server yang jelas dan kirim ISO 8601.
- Tambahkan unique constraint untuk username dan invoice.
- Tambahkan index pada `customer_id`, `created_at`, `estimated_finish_at`, `order_status`, dan `payment_status`.

## 12. Urutan Implementasi Backend yang Disarankan

### Tahap A - Akun Owner dan User Management

1. Tambahkan API user CRUD.
2. Tambahkan policy untuk super owner, owner, dan kasir.
3. Lengkapi response login dengan field user asli.
4. Implementasikan endpoint profil dan perubahan password.
5. Ganti `MockUserManagementRepository` dengan datasource/repository remote.
6. Tambahkan test authorization dan validasi user.

### Tahap B - Konsistensi transaksi dan collection

1. Tetapkan enum status final.
2. Pisahkan endpoint update biasa dari endpoint collect/settle jika diperlukan.
3. Tambahkan `paid_amount`, `paid_at`, `collected_at`, dan `collected_by`.
4. Tambahkan upload bukti optional.
5. Tambahkan test transisi status dan idempotency.

### Tahap C - Dashboard dan laporan

1. Buat endpoint summary dan queue.
2. Ganti angka dummy dashboard dengan data API.
3. Buat endpoint laporan dengan filter tanggal dan pagination.
4. Hubungkan export PDF/Excel.

### Tahap D - Optimasi dan audit

1. Tambahkan query search/filter/pagination server-side.
2. Tambahkan history pelanggan server-side.
3. Tambahkan audit log.
4. Tambahkan index database dan monitoring error.

## 13. Checklist Kesiapan Backend

- [ ] User CRUD sudah tersedia dan memakai policy.
- [ ] Owner dapat mengelola akun sesuai kewenangan.
- [ ] Login menolak user nonaktif.
- [ ] Response user tidak membutuhkan tambalan dummy di Flutter.
- [ ] Status transaksi memiliki enum dan transisi resmi.
- [ ] Pembayaran dan pengambilan tercatat dengan actor serta timestamp.
- [ ] Bukti pengambilan optional dapat diunggah ke server.
- [ ] Dashboard memakai summary dari API.
- [ ] Laporan memakai query server-side.
- [ ] Export PDF/Excel menghasilkan file nyata.
- [ ] History pelanggan memiliki endpoint pagination.
- [ ] Search/filter transaksi mendukung pagination.
- [ ] Audit log tersedia untuk aksi sensitif.
- [ ] Semua endpoint sudah diuji authorization dan validation.
