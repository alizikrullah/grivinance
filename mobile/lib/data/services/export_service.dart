import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/date_formatter.dart';
import '../models/transaction_model.dart';
import '../repositories/transaction_repository.dart';

/// Bikin file .xlsx dari transaksi dalam rentang tanggal, lalu serahkan ke
/// share sheet.
///
/// Sengaja `.xlsx`, bukan CSV. Excel dengan setelan regional Indonesia membaca
/// CSV dengan pemisah titik koma, jadi file berkoma menumpuk di satu kolom.
/// Lebih penting lagi, "150000.00" akan terbaca sebagai teks karena desimalnya
/// titik — tidak bisa di-SUM, padahal itu alasan utama orang export.
class ExportService {
  ExportService(this._repository);

  final TransactionRepository _repository;

  /// Endpoint transaksi dibatasi 100 per halaman, jadi diambil bertahap.
  static const int _pageSize = 100;

  /// Pagar supaya rentang tanggal yang kelewat lebar tidak menarik data tanpa
  /// henti kalau ada yang salah dengan penomoran halaman.
  static const int _maxPages = 200;

  Future<List<TransactionModel>> fetchRange({
    required DateTime start,
    required DateTime end,
  }) async {
    final filter = TransactionFilter(startDate: start, endDate: end);
    final all = <TransactionModel>[];

    for (var page = 1; page <= _maxPages; page++) {
      final result = await _repository.list(page: page, limit: _pageSize, filter: filter);
      all.addAll(result.items);
      if (!result.hasMore) break;
    }

    return all;
  }

  /// Balikin path file yang sudah ditulis.
  Future<String> buildWorkbook({
    required List<TransactionModel> transactions,
    required DateTime start,
    required DateTime end,
  }) async {
    final excel = Excel.createExcel();
    const sheetName = 'Transaksi';
    excel.rename(excel.getDefaultSheet()!, sheetName);
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Tanggal'),
      TextCellValue('Waktu'),
      TextCellValue('Tipe'),
      TextCellValue('Kategori'),
      TextCellValue('Wallet'),
      TextCellValue('Jumlah'),
      TextCellValue('Catatan'),
    ]);

    for (final tx in transactions) {
      final local = tx.date.toLocal();
      sheet.appendRow([
        DateCellValue.fromDateTime(local),
        TextCellValue(DateFormatter.time(local)),
        TextCellValue(tx.type.label),
        TextCellValue(tx.category.name),
        TextCellValue(tx.wallet.name),
        // Angka dikirim sebagai angka, bukan teks, supaya bisa langsung di-SUM.
        DoubleCellValue(tx.amount),
        TextCellValue(tx.note ?? ''),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) throw Exception('Gagal menyusun file Excel');

    final dir = await getTemporaryDirectory();
    final name =
        'grivinance_${DateFormatter.isoDate(start)}_${DateFormatter.isoDate(end)}.xlsx';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);

    return file.path;
  }

  /// Share sheet dipilih ketimbang menulis langsung ke Downloads: Android
  /// modern butuh izin storage untuk itu, sementara share sheet tidak butuh
  /// izin apa pun dan user bisa langsung kirim ke Drive atau simpan ke Files.
  Future<void> share(String path, {required DateTime start, required DateTime end}) {
    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Transaksi Grivinance',
        text: 'Transaksi ${DateFormatter.short(start)} — ${DateFormatter.short(end)}',
      ),
    );
  }
}
