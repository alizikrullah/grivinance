# Logo bank & e-wallet

Sudah aktif. Logo di sini muncul di picker form wallet, dikelompokkan jadi
**BANK** dan **E-WALLET**.

## Isi sekarang

| Bank | E-Wallet |
|---|---|
| `bca.png` | `gopay.png` |
| `bni.png` | `ovo.png` |
| `bri.png` | `dana.png` |
| `mandiri.png` | `shopeepay.png` |

## Cara nambah logo baru

1. Taruh filenya di folder ini
2. Daftarkan namanya di `lib/core/constants/app_icons.dart` → `AppLogos.banks`
   atau `AppLogos.eWallets` (tanpa `.png`)

Cuma dua langkah itu. `pubspec.yaml` sudah mendaftarkan seluruh folder, jadi
tidak perlu disentuh lagi.

## Aturan file

- **PNG transparan.** SVG butuh paket `flutter_svg` yang belum terpasang.
- Yang ada sekarang 240×120. Ukuran bebas, tapi jangan di bawah 120 px sisi
  terpanjang — logo tampil paling besar di layar detail transaksi (68 px).
- Potong padding kosongnya.

## Kenapa latarnya putih

Logo dirender di atas **latar putih**, bukan di atas warna wallet seperti
Material Icon. Bukan pilihan gaya: logo-logo ini dirancang untuk latar terang.
Wordmark `gopay` warnanya hitam — di atas latar gelap app atau di atas kotak
berwarna, dia hilang total.

## Bagaimana disimpan di database

Kolom `icon` diisi `logo:bca`, bukan `bca`. Prefiks itu yang membedakannya dari
nama Material Icon biasa, jadi satu kolom bisa menampung dua-duanya dan backend
tidak perlu diubah sama sekali.
