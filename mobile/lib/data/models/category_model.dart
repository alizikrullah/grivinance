enum TxType {
  income('income', 'Pemasukan'),
  expense('expense', 'Pengeluaran');

  const TxType(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static TxType fromApi(String value) =>
      value == 'income' ? TxType.income : TxType.expense;
}

class CategoryModel {
  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.isPreset,
  });

  final String id;
  final String name;
  final String icon;
  final String color;
  final TxType type;

  /// Kategori global (userId null) — tidak bisa diedit atau dihapus siapa pun.
  final bool isPreset;

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
    id: json['id'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
    type: TxType.fromApi(json['type'] as String),
    isPreset: json['userId'] == null,
  );
}
