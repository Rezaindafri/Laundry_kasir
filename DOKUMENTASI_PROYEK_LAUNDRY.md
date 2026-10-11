# Dokumentasi Proyek KarsaOne

Pembaruan: **11 Oktober 2026**, berdasarkan kode Flutter/Laravel, pengujian menyeluruh backend/Flutter serta migrasi tambahan tujuan pembayaran pada tanggal tersebut. Nama file historis dipertahankan agar tautan lama tetap berlaku.

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

Seluruh rute yang membutuhkan login berada di satu ShellRoute, untuk menghindari shell/Page key ganda ketika scanner atau halaman sementara membuka tab. Navigation bar tetap hanya tampil di tab utama. Perpindahan tab/aksi cepat memakai push agar Back mempertahankan riwayat; penutupan modal aksi cepat tidak menghapus halaman asal.

Back menutup popup/drawer terlebih dahulu, kemudian kembali satu halaman/tab. Jika masuk langsung ke tab/halaman sementara tanpa riwayat, Back menuju Beranda; hanya Beranda tanpa halaman sebelumnya yang meminta konfirmasi keluar. Selama request simpan/pembayaran/pengambilan berjalan, Back memberi pesan tunggu dan perpindahan tab/editing dinonaktifkan sementara. Pengunci dilepas pada hasil sukses maupun gagal; bukan pembatalan request server.

`showSafeModalBottomSheet` menunggu `ModalRoute.completed`, bukan hanya hasil pop, sebelum melepas controller lokal atau membuka sheet berikutnya. Form pelanggan utama tetap memiliki controller dalam State. Scanner berbagi controller dengan preview, berhenti saat tertutup/background/tertutup rute lain, dan mengabaikan hasil lookup setelah meninggalkan layar. Detail pengujian: [navigasi Back](docs/NAVIGASI_BACK_2026-10-11.md).

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
- Estimasi 0 atau kosong disimpan sebagai 0: barang tanpa proses langsung siap dan tidak otomatis terlambat. Unit hari dikonversi menjadi jam sebelum dikirim ke Laravel.

Transaksi:

- Query pencarian, status, pembayaran, tanggal, akun dan pagination backend.
- Satu transaksi/bon memuat 1–50 baris layanan, dengan kuantitas, harga, biaya Express dan estimasi per baris. Nama/unit/harga/estimasi disalin saat transaksi dibuat agar perubahan katalog tidak mengubah bon lama.
- Form Transaksi Baru menyatukan layanan dalam satu daftar kartu. Kartu pertama langsung tersedia; Tambah layanan menambahkan kartu kosong dengan pemilihan/jumlah/estimasi yang sama. Kartu mana pun boleh dihapus jika masih ada layanan lain; Express berada setelah daftar. Nilai controller tetap diperiksa saat simpan walaupun kartunya sudah di-scroll keluar layar.
- Daftar pilihan pelanggan dan layanan mengamati provider API selama pencarian terbuka. Hasil yang terlambat tiba langsung ditampilkan; loading, kegagalan, katalog kosong dan pencarian tanpa hasil dibedakan. Coba lagi/perbarui mengambil ulang API tanpa kehilangan kata pencarian. Urutan nama A–Z mengabaikan kapital dan spasi luar, tidak bergantung pada nomor HP. Kartu layanan terpilih ikut A–Z dengan draft/controller jumlah tetap melekat; kartu belum dipilih tetap di bagian bawah. Tidak mengubah data pelanggan/layanan atau urutan bon lama di database.
- Estimasi transaksi adalah waktu selesai paling akhir dari layanan berestimasi, bukan jumlah durasinya. Bon, detail dan pengambilan menampilkan estimasi tiap layanan.
- Pencatatan pelanggan, layanan, kuantitas, catatan, metode dan pembayaran awal; DP saat pembuatan memakai nominal yang benar-benar dimasukkan.
- Invoice/QR mengidentifikasi transaksi. Transaksi baru diarahkan ke detail.
- Update/hapus umum hanya Owner. Pembayaran melalui payment, pengambilan melalui collection.
- Transaksi dibayar/diambil mempunyai perlindungan penghapusan.
- Diskon, refund dan pembatalan finansial bukan alur lengkap saat ini; placeholder bukan implementasi refund.

Express sudah terintegrasi: request mengirim penanda Express per baris; Laravel menghitung tambahan 25% dan membulatkan nominal transaksi baru ke rupiah. Harga client tetap tidak dipercaya. Harga/nominal transaksi lama tidak ditulis ulang.

## 6. Pembayaran dan status resmi

payment_status: unpaid, downPayment, paid.
laundry_status: received, washing, drying, ironing, completed, late, collected.

| Istilah UI | Definisi saat ini |
| --- | --- |
| Diproses | Ada baris belum diambil yang masih sebelum estimasi selesai |
| Selesai / siap diambil | Baris completed atau late yang belum diambil; barang berestimasi 0 langsung siap |
| Belum diambil | Ada minimal satu baris siap yang belum diambil; baris lain boleh masih diproses |
| Terlambat | Ada baris berestimasi yang belum diambil dan melewati dua kali durasi dari waktu transaksi dibuat |
| Sudah diambil | Semua baris sudah diambil melalui pengambilan resmi dan seluruh tagihan lunas |

Durasi 2 jam: estimasi jam ke-2; late setelah jam ke-4. Perbandingan memakai >; tepat pada batas belum late. Otomatisasi estimasi adalah aturan aplikasi sekarang, bukan bukti pemeriksaan fisik pekerjaan.

Status transaksi gabungan: collected jika seluruh baris diambil; late jika ada sisa baris terlambat; completed jika seluruh sisa baris siap; selain itu status proses. Satu transaksi campuran boleh masuk kartu Diproses sekaligus Belum Diambil, karena baris berbeda. Kartu menghitung jumlah transaksi, bukan jumlah baris; filter backend memakai definisi yang sama.

Scheduler laundry:sync-statuses setiap menit dengan withoutOverlapping. Sebagian endpoint juga menyinkronkan kelompok saat request. Tes memakai waktu virtual; cron hosting belum diverifikasi.

Pembayaran:

- “Bayar Saja” membuka input nominal diterima, metode dan catatan opsional; bisa DP/pelunasan sebelum siap, nonaktif setelah lunas. Pembayaran tidak otomatis mengambil barang.
- Tujuan pembayaran milik Owner tersedia untuk Owner/Kasir kelompok yang sama: QRIS menampilkan gambar privat, transfer menampilkan pilihan beberapa bank/rekening/pemilik, tunai tanpa pilihan tambahan. Transaksi Baru, Bayar Saja dan Bayar & Ambil mengirim `payment_destination_id` ke Laravel ketika ada pembayaran baru. Laravel menolak tujuan nonaktif, salah metode atau milik Owner lain. Jika sudah dikonfigurasi untuk metode tersebut, pemilihan tujuan diwajibkan backend; metode lama tanpa konfigurasi tetap kompatibel.
- Ledger menyimpan ID tujuan dan snapshot label bank/tujuan saat pembayaran, tanpa menyalin nomor rekening plaintext. Retry UUID yang sama harus mempertahankan tujuan, nominal, metode dan catatan; tidak membuat pembayaran kedua. Detail mengambil `GET /transactions/{id}` dan menampilkan tanggal/nominal/metode/tujuan/pencatat/catatan yang benar-benar tersedia.
- Bagian Bukti pengambilan di Detail menampilkan pratinjau dan tombol foto per baris layanan; dapat diperbesar melalui akses API berizin. Foto lama yang tersedia juga dapat dilihat. Foto opsional dan bukan bukti transfer; alur upload bukti pembayaran baru tidak ditambahkan pada tahap ini.
- “Bayar & Ambil” memilih baris layanan siap dan mencatat nominal tambahan yang menutup nilai layanan yang diambil; menjadi “Ambil” jika sudah lunas.
- Nominal awal otomatis: Transaksi Baru memakai total seluruh layanan termasuk Express; Bayar Saja memakai sisa tagihan, bukan total sebelum DP; Bayar & Ambil memakai kebutuhan pembayaran layanan terpilih setelah memperhitungkan DP/pengambilan terdahulu. Pengambilan terakhir memakai seluruh sisa bon, dan transaksi lunas memakai 0 tanpa pembayaran tambahan.
- Kolom angka otomatis terseleksi saat disentuh, sehingga ketikan pertama mengganti angka tersebut, bukan menambah digit di belakangnya. Setelah diedit, kursor bekerja normal dan nominal manual tidak diisi ulang ketika layanan/berat/Express berubah. Nominal otomatis yang belum diedit mengikuti perubahan tagihan.
- Pada Transaksi Baru, kolom pembayaran tersedia untuk pilihan Lunas/DP; nominal penuh otomatis berstatus Lunas, nominal sebagian berstatus DP. Memilih Lunas secara eksplisit mengembalikan nominal ke total terkini. Belum Bayar tetap mengirim 0. Nominal kosong, 0 pada pilihan membayar, atau melebihi tagihan ditolak sebelum dikirim; Laravel tetap menghitung harga/status dan memvalidasi pembayaran secara otoritatif.
- Retry Bayar Saja mempertahankan nominal/metode/catatan dan ID request yang gagal bila tidak diubah, bukan menggantinya dengan autofill; perubahan nominal menghasilkan ID baru sesuai mekanisme yang ada.
- Pengambilan sebelum siap ditolak Laravel. Berlaku untuk seluruh kuantitas baris terpilih; pengambilan sebagian kuantitas satu baris belum tersedia. Foto opsional.
- DP sebelumnya mengurangi kebutuhan bayar. Pengambilan terakhir wajib melunasi seluruh bon; pengambilan awal dapat menyisakan DP dan baris belum diambil.
- Setelah API pembayaran/pengambilan menyatakan sukses, layar kembali otomatis ke pencarian Pengambilan dan mengambil ulang daftar dari backend. Filter/pencarian halaman asal dipertahankan; transaksi `collected` tidak muncul lagi, sedangkan pembayaran saja dan pengambilan sebagian tetap terdaftar dengan status terbaru. Kegagalan API tetap menahan pengguna di formulir agar dapat dicoba lagi.
- Back dari detail/pengambilan juga memuat ulang daftar. Refresh tarik-ke-bawah tersedia pada daftar panjang, pendek, kosong maupun gagal dimuat; respons pagination yang berasal dari query sebelum refresh diabaikan agar tidak mengembalikan transaksi yang sudah diambil.
- File baru disimpan privat; GET `/transactions/{id}/proof?detail_id=...` membaca bukti per baris dengan autentikasi, role dan scope Owner. URL statis bukti lama ditolak melalui aturan server yang perlu diverifikasi pada hosting.
- Boolean multipart harus sesuai validator Laravel; collection dengan 0/1 diuji.

POST /transactions/{id}/payment kini menerima **amount tambahan** + request_id UUID, payment_method dan payment_note opsional. Retry payload yang sama dengan UUID yang sama tidak menggandakan ledger/audit. Kontrak lama paid_amount kumulatif tetap diterima; jangan mengirim kedua jenis nominal bersamaan.

Contoh: layanan A Rp30.000, B Rp50.000, DP Rp20.000. Saat A siap, bayar tambahan Rp10.000 dan ambil A: saldo pembayaran Rp30.000/DP, B tetap terbuka. Pembayaran berikutnya Rp50.000 dicatat pada tanggal pembayaran itu; ambil B tanpa membayar lagi setelah siap. Total ledger tepat Rp80.000.

`collected` kini terminal pada update/status umum. Mutasi transaksi dan scheduler membaca ulang baris dengan lockForUpdate dalam DB transaction. Retry saldo kumulatif sama menjadi no-op tanpa ledger/audit tambahan; pembayaran lebih kecil ditolak. Pengambilan memeriksa saldo, bukan hanya label paid. Request paralel MySQL belum diuji; bukan idempotency-key untuk create pesanan. Bukti baru dibersihkan saat rollback tanpa menghapus bukti lama.

Pengambilan bertahap mencatat waktu/pelaku/bukti per baris dan audit transaction.partially_collected atau transaction.collected dalam transaksi database yang sama. Endpoint bukti lama hanya menandai sisa baris, tanpa menimpa bukti/waktu/pelaku pengambilan sebelumnya.

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
- Catatan pembayaran tambahan ditampilkan pada rincian dan CSV; filter/tanggal tetap berdasarkan event pembayaran, bukan jumlah baris layanan.
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
- Setting → Tujuan pembayaran: Owner menambah/mengubah/menonaktifkan QRIS atau beberapa rekening. Nomor rekening memakai encrypted cast Laravel pada kolom TEXT; tidak tersimpan di preferences Flutter dan tidak masuk audit/log request. Gambar QRIS disimpan privat pada disk `proofs/payment-qris`, dibatasi JPG/PNG/WebP, 2 MB, maksimal 2048 × 2048. Kasir hanya membaca tujuan aktif milik kelompoknya; Super Owner tidak memperoleh fitur operasional ini.
- Tujuan tidak dihapus agar ledger historis tetap terhubung. Label historis pembayaran dipertahankan saat nama/rekening diubah. `APP_KEY` harus disimpan privat dan dibackup aman; jangan menjalankan key regeneration sembarangan. Enkripsi penyimpanan tidak menggantikan HTTPS.
- Printer/default MAC/ukuran kertas adalah preferensi perangkat, bukan konfigurasi global server.
- Super Owner memakai settings akun/sistem, bukan printer/informasi usaha pribadinya.
- Backup v2 owner_configuration_backup berisi konfigurasi usaha, **bukan** database/akun/password/pelanggan/transaksi.
- Backup konfigurasi tersebut juga belum mencakup tujuan pembayaran dan gambar QRIS. Backup server harus mencakup database/file privat dan kunci enkripsi yang dilindungi, bukan hanya ekspor konfigurasi UI.
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

Kedua jenis bon menampilkan seluruh baris layanan, kuantitas/subtotal dan estimasi kecil di masing-masing layanan, pembayaran diterima/sisa tagihan, serta penanda baris yang sudah diambil. QR tetap mengidentifikasi satu transaksi.

Batas:

- Printer service mendukung Android; platform lain memakai stub/penolakan.
- Direct-share WhatsApp Android; WhatsApp biasa/Business/nomor belum disimpan perlu tes perangkat.
- Controller scanner sudah dipasang ke MobileScanner dan diuji dengan mock lifecycle/Back; pengujian kamera fisik tetap diperlukan.
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
| Tujuan pembayaran | GET /settings/payment-destinations; GET /settings/payment-destinations/{id}/image | Owner/Kasir, kelompok sendiri; Kasir hanya tujuan aktif |
| Kelola tujuan | POST /settings/payment-destinations; PATCH /settings/payment-destinations/{id} | Owner, kelompok sendiri; multipart update dapat memakai POST + _method=PATCH |
| Sistem | GET/PATCH /system-settings; GET /account-policy | Super Owner; policy juga Owner |
| Config backup | GET /settings/backup; POST /settings/restore | Super Owner |

Sebagian deklarasi role master data menyebut Super Owner, tetapi OwnerScopeService menolak operasional tersebut. Inkonsistensi deklarasi, bukan izin monitoring penuh.

## 11. Verifikasi dan keselamatan data

Migrasi maju 2026_10_10_000006 sudah diterapkan pada Laragon setelah pemeriksaan pending dan checksum read-only sebelum/sesudah. Kolom asli transaksi/detail/pembayaran serta metadata pelanggan/layanan yang dibandingkan tetap identik. Tidak reset, menghapus data, seed akun nyata, atau mengubah kredensial/config produksi. PHPUnit menjalankan migrasi fixture pada SQLite :memory: dengan environment testing, DB_URL kosong, cache/session array, queue sync. Upload memakai storage fake.

- Backend normal dan regresi terbaru: 95/95 lulus, 707 assertions; termasuk 8 tes baru/86 assertions tujuan pembayaran, enkripsi, validasi upload, isolasi Owner, ledger, rollback pengambilan dan retry setelah tujuan dinonaktifkan.
- Audit tambahan: 13/13 lulus, 105 assertions; sebelumnya 9 gagal.
- Flutter: 138 lulus pada 11 Oktober; 12 regresi tambahan meliputi rekening/QRIS, kegagalan/retry pemilihan, foto detail, callback navigasi yang tidak dipicu popup, payload tujuan pada create/pay/collect dan riwayat legacy. Regresi nominal otomatis/manual, pengambilan kembali/refresh, popup/Back/scanner, pilihan, bon, login dan WIB tetap lulus tanpa API/perangkat nyata.
- Regresi daftar Pengambilan memeriksa pembayaran penuh/sebagian, pengambilan lunas/sebagian, kegagalan API, Back/pembatalan modal, pencarian yang dipertahankan, pull refresh kosong/pendek/error, respons pagination terlambat serta masuk dari detail/rute QR. Tidak mengubah Laravel/database pada tahap navigasi; tetap menggunakan repository dan endpoint produksi yang sudah ada, tetapi tes baru memakai repository tiruan.
- Laravel: 3 regresi pembayaran/pengambilan bertahap/idempotensi dan penolakan akses owner lain diulang 11 Oktober; 35 assertions lulus memakai SQLite di memori, tanpa database Laragon. Tidak mengubah kode backend pada tahap autofill ini.
- Dart lib/test terbaru: 0 error, 11 warning dan 1016 lint/hint informasi. Warning tersisa pada model auth/dashboard Owner lama. Bukan pernyataan bahwa seluruh proyek bebas lint. Keyboard Android/iOS fisik dan E2E server nyata belum diuji; tidak menjalankan build Gradle atau mengunduh dependensi pada tahap ini.
- Composer runtime dan seluruh lockfile: 0 advisori setelah upgrade tiga paket; validasi Composer dan persyaratan platform lokal lolos.

Cara testing aman di README. UI test tidak memakai API nyata; API test tidak memakai database pelanggan asli. Tes injection/upload adalah sampel negatif, bukan penetration test lengkap.

Migrasi tambahan `2026_10_11_000007_add_owner_payment_destinations.php` telah diterapkan pada Laragon lokal: tabel baru dan dua kolom nullable ledger, tanpa reset/seed/hapus data. Pemeriksaan sebelum/sesudah membandingkan jumlah baris dan checksum seluruh kolom lama pada users/customers/services/transactions/transaction_details/transaction_payments/laundry_settings; identik. Script lokal `scripts/verify_payment_destination_migration.php` menolak lingkungan produksi/non-MySQL/non-localhost; tanpa `--apply` hanya memeriksa. Tidak memasukkan QRIS/rekening nyata untuk tes.

Refresh navigasi memuat data server saat membuka/kembali ke halaman, tanpa mereset filter/draft atau auth/router. Data yang belum pernah dimuat tidak diminta dua kali saat mount. Menutup dialog/bottom sheet tidak memicu reload; refresh daftar sesudah pembayaran yang sudah dijalankan tidak digandakan. Refresh mengikuti role (Super Owner tetap struktur akun saja), bukan polling background atau jaminan live update selama pengguna diam di halaman. Detail kontrak dan cek manual: [tujuan pembayaran dan refresh](docs/TUJUAN_PEMBAYARAN_REFRESH_2026-10-11.md).

## 12. Temuan terbuka dan urutan lanjutan

Sudah ditangani dalam kode: logout/revokasi/expiry/rate limit/sesi Flutter, terminal collected + row lock/retry pembayaran, restore atomik, larangan downgrade Owner bertanggungan, error generik dan formula CSV. Super Owner tetap hanya mengelola struktur akun/sistem.

Yang masih perlu dilakukan:

1. Verifikasi aturan file statis hosting (termasuk Nginx/CDN), serta penolakan URL bukti lama tanpa token. Kode WIB/akses privat/upgrade sudah diuji, bukan bukti hosting sudah terkonfigurasi.
2. Uji Back fisik/predictive Back, keyboard dan lifecycle kamera pada Android nyata; controller scanner sudah terpasang dan lolos mock. Periksa cache settings/rollover dan atribusi riwayat legacy. Uji nominal/bon multi-layanan, cetak dan WhatsApp pada perangkat nyata.
3. Uji paralel MySQL pada database test terpisah dan E2E perangkat/staging.
4. Tuntaskan penanganan token/history pada seluruh salinan backend dan verifikasi deployment HTTPS/docroot/env/DB permissions/firewall/cron.

[Audit awal](docs/AUDIT_INTEGRASI_KEAMANAN_2026-10-10.md) dan [tahap pertama](docs/PERBAIKAN_PRIORITAS_2026-10-10.md) adalah snapshot historis. [WIB, bukti dan upgrade](docs/TIMEZONE_BUKTI_DEPENDENSI_2026-10-10.md) memuat kelanjutan terbaru dan batas deployment.

[Multi-layanan dan pembayaran bertahap](docs/MULTI_LAYANAN_PEMBAYARAN_2026-10-10.md) memuat kontrak request, contoh dan kebijakan data lama.

## 13. Git dan deployment

.gitignore kedua repo mencakup env varian, kunci privat/signing, konfigurasi HTTP privat, cache/log dan backup/data lokal. Source, lockfile, migrasi, contoh env tanpa rahasia, aset dan tes tidak dihapus.

api_test.http backend masih tracked tetapi isi kerja sekarang memakai placeholder; fingerprint token terpapar diblokir Sanctum. Riwayat awal tetap mengandung token. Tidak menghapus baris token nyata, mengubah indeks, rewrite history atau rotasi kredensial. Semua salinan backend harus menerima mitigasi; koordinasikan history cleanup sebelum repo dibagikan.

Produksi: .env privat di luar docroot, debug mati, HTTPS, akun DB khusus/izin minimum, DB tidak terbuka ke internet, scheduler aktif, penyimpanan bukti berizin. Audit kode tidak membuktikan kondisi hosting.

Informasi usaha, backup dan bukti mengandung data pelanggan: batasi akses, retensi dan salinan. Backup konfigurasi bukan strategi backup database.
