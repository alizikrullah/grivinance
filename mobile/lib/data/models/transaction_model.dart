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
}

class TransactionModel {
  const TransactionModel({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    required this.wallet,
    required this.category,
    this.note,
  });

  final String id;
  final String walletId;
  final String categoryId;
  final TxType type;
  final double amount;
  final DateTime date;
  final TxRef wallet;
  final TxRef category;
  final String? note;

  bool get isIncome => type == TxType.income;

  factory TransactionModel.fromJson(Map<String, dynamic> json) => TransactionModel(
        id: json['id'] as String,
        walletId: json['walletId'] as String,
        categoryId: json['categoryId'] as String,
        type: TxType.fromApi(json['type'] as String),
        amount: double.parse(json['amount'] as String),
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        wallet: TxRef.fromJson(json['wallet'] as Map<String, dynamic>),
        category: TxRef.fromJson(json['category'] as Map<String, dynamic>),
      );
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
