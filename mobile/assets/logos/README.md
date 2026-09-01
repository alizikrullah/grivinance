# Logo bank & e-wallet

Taruh file logo di folder ini. Sudah didaftarkan di `pubspec.yaml`, jadi file
baru langsung kebaca tanpa ubah konfigurasi apa pun.

## Aturan penamaan

Nama file jadi **identitas logo di database**, jadi pakai huruf kecil dan garis
bawah, tanpa spasi:

```
assets/logos/bca.png
assets/logos/bni.png
assets/logos/gopay.png
assets/logos/dana.png
assets/logos/ovo.png
assets/logos/shopeepay.png
```

## Format

- **PNG transparan** atau **SVG**. PNG paling aman — SVG butuh package tambahan
  (`flutter_svg`) yang belum terpasang.
- Ukuran **192×192 px** cukup. Icon tampil paling besar di layar detail
  transaksi (68 px), jadi 192 sudah aman sampai layar 3x.
- Logo dirender di dalam kotak berwarna, jadi **potong padding kosongnya** biar
  logonya nggak kelihatan kekecilan.

## Setelah file ditaruh

Kode belum bisa memilih logo ini — masih pakai Material Icons. Yang perlu
ditambah nanti:

1. Daftar nama logo di `lib/core/constants/app_icons.dart`
2. Cabang di `GriviIconBadge`: kalau nama diawali `logo:` render `Image.asset`,
   selain itu render `Icon` seperti sekarang
3. Tab kedua di `IconPickerField` — "Logo" di sebelah "Icon"

Backend tidak perlu diubah sama sekali. Kolom `icon` sudah berupa String, jadi
cukup diisi `logo:bca` alih-alih `account_balance`.
