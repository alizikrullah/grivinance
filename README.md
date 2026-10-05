# Grivinance

Aplikasi pencatatan keuangan personal untuk pengguna Indonesia. Mendukung
banyak dompet sekaligus — e-wallet, rekening bank, dan uang tunai — dengan
saldo tiap dompet yang selalu ikut menyesuaikan setiap kali ada transaksi.

Monorepo: REST API di `backend/`, aplikasi Android di `mobile/`.

<p align="center">
  <img src="docs/screenshots/dashboard.png" width="240" alt="Beranda">
  <img src="docs/screenshots/grafik.png" width="240" alt="Grafik">
  <img src="docs/screenshots/akun.png" width="240" alt="Akun">
</p>

## Fitur

- **Multi-wallet** — e-wallet, bank, dan tunai dengan ikon, warna, dan logo
  bank/e-wallet asli, plus riwayat per wallet
- **Transaksi** — pemasukan, pengeluaran, dan **transfer antar wallet** dengan
  biaya admin opsional; filter tipe, wallet, kategori, dan rentang tanggal
- **Budget** — batas pengeluaran bulanan per kategori dengan progres terpakai
- **Gamifikasi** — streak harian, misi harian dengan XP, level bergelar, dan
  9 lencana pencapaian
- **Kategori** — 17 preset global plus kategori buatan sendiri
- **Grafik** — donut interaktif per kategori (harian dan bulanan) serta grafik
  batang 12 bulan
- **Profil** — foto profil, nama panggilan, nomor HP, tanggal lahir, ganti
  email dan password
- **Export Excel** — pilih rentang tanggal, hasilnya `.xlsx` dengan kolom
  pemasukan, pengeluaran, dan transfer yang bisa langsung dijumlah
- **Autentikasi JWT** — access token berumur pendek, refresh token yang
  berotasi sehingga sesi tidak habis selama aplikasi dipakai

## Stack

| Bagian | Teknologi |
|---|---|
| Mobile | Flutter 3.47, Riverpod, Dio, go_router, fl_chart |
| Backend | Node.js 20, Express 5, TypeScript |
| Database | PostgreSQL 18 + Prisma 7 |
| Deploy | Docker, Coolify, Cloudflare Tunnel |

## Struktur

```
backend/
├── prisma/           skema database + seeder kategori preset
├── src/
│   ├── controllers/  parsing request, tidak ada logika bisnis
│   ├── services/     seluruh logika bisnis
│   ├── routes/       definisi endpoint + validasi input
│   ├── middlewares/  autentikasi, penanganan hasil validasi
│   └── utils/        JWT, format respons, rentang tanggal WIB
└── test/             uji end-to-end lewat HTTP

mobile/
└── lib/
    ├── core/         tema, router, konstanta, formatter
    ├── data/         model, repository, klien HTTP, secure storage
    ├── providers/    state Riverpod
    └── presentation/ layar dan widget
```

## Menjalankan secara lokal

### Backend

```bash
cd backend
npm install
cp .env.example .env        # isi DATABASE_URL dan secret-nya
npx prisma migrate dev
npx prisma db seed
npm run dev
```

Butuh PostgreSQL yang bisa diakses. Semua variabel yang wajib diisi ada di
`.env.example`.

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Alamat API default menunjuk ke server produksi. Untuk menunjuk ke backend lokal:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

## API

Base URL produksi: `https://backend-grivinance.grivilabs.my.id`

Semua endpoint kecuali `/health` dan auth membutuhkan header
`Authorization: Bearer <access_token>`.

```
GET    /health

POST   /api/auth/register
POST   /api/auth/login
POST   /api/auth/refresh          { refreshToken, rotate? }
DELETE /api/auth/logout
GET    /api/auth/me
PUT    /api/auth/me               nama, nama panggilan, nomor HP, tanggal lahir
PUT    /api/auth/me/email
PUT    /api/auth/me/password
GET    /api/auth/me/avatar
PUT    /api/auth/me/avatar        byte gambar mentah (JPEG/PNG/WebP, maks 1 MB)
DELETE /api/auth/me/avatar

GET    /api/wallets
POST   /api/wallets
PUT    /api/wallets/:id
DELETE /api/wallets/:id

GET    /api/categories
POST   /api/categories
PUT    /api/categories/:id
DELETE /api/categories/:id

GET    /api/transactions          ?page &limit &walletId &categoryId &type
                                  &startDate &endDate
GET    /api/transactions/:id
POST   /api/transactions          type income|expense|transfer
PUT    /api/transactions/:id
DELETE /api/transactions/:id

GET    /api/summary/daily         ?date=2026-09-01
GET    /api/summary/monthly       ?year=2026&month=9
GET    /api/summary/yearly        ?year=2026

GET    /api/budgets               ?year=2026&month=9
PUT    /api/budgets/:categoryId
DELETE /api/budgets/:categoryId

GET    /api/gamification          streak, misi, XP, level, lencana
POST   /api/gamification/missions/:key/claim
```

Seluruh respons memakai bentuk yang sama:

```json
{ "success": true, "message": "Berhasil", "data": {} }
```

## Pengujian

```bash
cd backend && npm test     # 95 pemeriksaan
cd mobile  && flutter test # 18 pemeriksaan
```

Selain uji integrasi, Flutter punya *smoke test* yang merender setiap layar
dengan API tiruan — dalam keadaan berisi data, akun kosong, dan belum login —
supaya kesalahan tata letak tertangkap sebelum aplikasi dipasang di HP.

Uji backend menjalankan aplikasi sungguhan di port acak dan memanggilnya lewat
HTTP, jadi yang diuji adalah perilaku endpoint, bukan fungsi yang dipanggil
langsung. Uji Flutter menembak API yang sedang berjalan untuk memastikan model
Dart benar-benar cocok dengan bentuk respons server.

Keduanya membutuhkan database yang bisa diakses.

## Catatan teknis

**Batas hari mengikuti WIB, bukan UTC.** Tanggal disimpan dalam UTC, tetapi
ringkasan dihitung memakai batas hari UTC+7. Tanpa ini, transaksi pukul 00:00
sampai 07:00 WIB akan masuk ke hitungan hari sebelumnya. Konversinya terpusat di
`utils/date.utils.ts`, dan ketiga endpoint ringkasan wajib melewatinya.

**Nominal uang dikirim sebagai string.** `Decimal` milik Prisma tidak menjadi
`number` ketika di-JSON-kan. API selalu mengirim `"150000.00"`, dan seluruh
perhitungan di server memakai `Decimal` — tidak pernah dikonversi ke `number`
lebih dulu, karena floating point menyimpang pada angka besar.

**Saldo wallet diperbarui secara atomik.** Setiap penambahan, perubahan, dan
penghapusan transaksi mengubah saldo wallet di dalam satu transaksi database,
sehingga catatan transaksi dan saldo tidak bisa berbeda. Semua perubahan saldo
lewat satu fungsi efek: perubahan transaksi berarti membatalkan efek baris lama
lalu menerapkan efek baris baru, jadi pindah wallet, ganti tipe, dan ganti biaya
admin tidak butuh kasus khusus.

**Transfer bukan pemasukan maupun pengeluaran.** Transfer memindahkan uang antar
wallet milik user sendiri, jadi tidak ikut dihitung di ringkasan maupun budget.
Biaya admin-nya disimpan sebagai pengeluaran terpisah yang menempel ke transfer
— uangnya benar-benar keluar, jadi tetap terhitung.

**Gamifikasi dihitung di server.** Streak, penyelesaian misi, dan syarat lencana
diturunkan dari data transaksi. Klaim misi divalidasi server dan dijaga unique
constraint, sehingga tidak bisa diakali dari aplikasi maupun diklaim dua kali.

**Saldo awal terkunci setelah ada transaksi.** Selama sebuah wallet belum punya
transaksi, saldo awalnya masih boleh disunting. Setelah ada, saldo merupakan
gabungan saldo awal dan seluruh transaksi — dua komponen yang tidak disimpan
terpisah — sehingga menimpanya membuat angkanya tidak bisa
dipertanggungjawabkan. Aturan ini dijaga di server, bukan sekadar disembunyikan
di antarmuka.

**Kategori preset tidak bisa disentuh.** Kategori global (`userId` bernilai
null) tidak dapat diubah atau dihapus oleh siapa pun. Kategori yang masih
dipakai transaksi juga ditolak untuk dihapus, dengan pesan yang menyebutkan
jumlah transaksinya.

**Seeder aman dijalankan berulang.** Seeder berjalan setiap kali container
dinyalakan, sehingga memakai `upsert` dengan id tetap.

## Lisensi

Proyek pribadi, tidak untuk didistribusikan ulang.
