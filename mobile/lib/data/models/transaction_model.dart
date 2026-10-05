import 'category_model.dart';

/// Ringkasan wallet/kategori yang ikut nempel di tiap transaksi,
/// supaya list nggak perlu query terpisah.
class TxRef {
  const TxRef({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  final String id;
  final String name;
  final String icon;
  final String color;

  factory TxRef.fromJson(Map<String, dynamic> json) => TxRef(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
  );

  static TxRef? maybe(Object? json) =>
      json == null ? null : TxRef.fromJson(json as Map<String, dynamic>);
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    required this.date,
    required this.wallet,
    this.categoryId,
    this.category,
    this.toWalletId,
    this.toWallet,
    this.fee,
    this.feeForId,
    this.note,
  });

  final String id;
  final String walletId;
  final TxType type;
  final double amount;
  final DateTime date;
  final TxRef wallet;
  final String? note;

  /// Pemasukan/pengeluaran punya kategori; transfer tidak.
  final String? categoryId;
  final TxRef? category;

  /// Wallet tujuan, cuma ada di transfer.
  final String? toWalletId;
  final TxRef? toWallet;

  /// Biaya admin transfer ini (null kalau tanpa biaya).
  final double? fee;

  /// Terisi kalau baris ini biaya admin yang dibuat otomatis oleh sebuah
  /// transfer. Baris seperti ini diubah/dihapus lewat transfernya.
  final String? feeForId;

  bool get isIncome => type == TxType.income;
  bool get isTransfer => type == TxType.transfer;
  bool get isFee => feeForId != null;

  /// Judul baris di daftar: nama kategori, atau "Transfer".
  String get title => isTransfer ? 'Transfer' : (category?.name ?? '-');

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
    id: json['id'] as String,
    walletId: json['walletId'] as String,
    categoryId: json['categoryId'] as String?,
    toWalletId: json['toWalletId'] as String?,
    feeForId: json['feeForId'] as String?,
    type: TxType.fromApi(json['type'] as String),
    amount: double.parse(json['amount'] as String),
    fee: json['fee'] == null ? null : double.parse(json['fee'] as String),
    date: DateTime.parse(json['date'] as String),
    note: json['note'] as String?,
    wallet: TxRef.fromJson(json['wallet'] as Map<String, dynamic>),
    category: TxRef.maybe(json['category']),
    toWallet: TxRef.maybe(json['toWallet']),
  );
}

/// Isi form transaksi yang dikirim ke API.
class TransactionInput {
  const TransactionInput({
    required this.type,
    required this.walletId,
    required this.amount,
    required this.date,
    this.categoryId,
    this.toWalletId,
    this.fee,
    this.note,
  });

  final TxType type;
  final String walletId;
  final String? categoryId;
  final String? toWalletId;
  final double amount;
  final double? fee;
  final DateTime date;
  final String? note;

  Map<String, dynamic> toJson() {
    final trimmedNote = note?.trim();
    return {
      'type': type.apiValue,
      'walletId': walletId,
      if (type == TxType.transfer) 'toWalletId': toWalletId else 'categoryId': categoryId,
      'amount': amount.toStringAsFixed(2),
      if (type == TxType.transfer && (fee ?? 0) > 0) 'fee': fee!.toStringAsFixed(2),
      // UTC eksplisit. DateTime lokal di-toIso8601String() keluar TANPA offset,
      // dan server di UTC membacanya sebagai jam UTC — geser 7 jam (BUG-2).
      'date': date.toUtc().toIso8601String(),
      'note': (trimmedNote == null || trimmedNote.isEmpty) ? null : trimmedNote,
    };
  }
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  final List<TransactionModel> items;
  final int page;
  final int totalPages;
  final int total;

  bool get hasMore => page < totalPages;

  factory TransactionPage.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>;
    return TransactionPage(
      items: (json['items'] as List<dynamic>)
          .map((e) => TransactionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      page: pagination['page'] as int,
      totalPages: pagination['totalPages'] as int,
      total: pagination['total'] as int,
    );
  }
}

/// Filter buat GET /api/transactions.
class TransactionFilter {
  const TransactionFilter({
    this.walletId,
    this.categoryId,
    this.type,
    this.startDate,
    this.endDate,
  });

  final String? walletId;
  final String? categoryId;
  final TxType? type;
  final DateTime? startDate;
  final DateTime? endDate;

  bool get isEmpty =>
      walletId == null &&
      categoryId == null &&
      type == null &&
      startDate == null &&
      endDate == null;

  TransactionFilter copyWith({
    String? walletId,
    String? categoryId,
    TxType? type,
    DateTime? startDate,
    DateTime? endDate,
    bool clearWallet = false,
    bool clearCategory = false,
    bool clearType = false,
    bool clearDates = false,
  }) {
    return TransactionFilter(
      walletId: clearWallet ? null : (walletId ?? this.walletId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      type: clearType ? null : (type ?? this.type),
      startDate: clearDates ? null : (startDate ?? this.startDate),
      endDate: clearDates ? null : (endDate ?? this.endDate),
    );
  }
}
