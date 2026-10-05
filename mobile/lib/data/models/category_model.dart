enum TxType {
  expense('expense', 'Pengeluaran'),
  income('income', 'Pemasukan'),
  transfer('transfer', 'Transfer');

  const TxType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  /// Kategori cuma punya dua tipe; transfer nggak berkategori.
  static const List<TxType> categoryTypes = [TxType.expense, TxType.income];

  static TxType fromApi(String value) =>
      TxType.values.firstWhere((t) => t.apiValue == value, orElse: () => TxType.expense);
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isPreset,
    required this.transactionCount,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final TxType type;

  /// Kategori global (userId null) — tidak bisa diedit atau dihapus siapa pun.
  final bool isPreset;

  /// Jumlah transaksi milik user yang memakai kategori ini.
  final int transactionCount;

  /// Tipe kategori yang udah dipakai dikunci server (409), jadi form ikut menguncinya.
  bool get canChangeType => transactionCount == 0;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
    type: TxType.fromApi(json['type'] as String),
    isPreset: json['userId'] == null,
    transactionCount: json['transactionCount'] as int? ?? 0,
  );
}
