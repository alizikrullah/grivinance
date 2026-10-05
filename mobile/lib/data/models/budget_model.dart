class BudgetItem {
  const BudgetItem({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
    required this.spent,
  });

  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final double amount;
  final double spent;

  double get remaining => amount - spent;

  /// 0..∞ — lewat 1 berarti budgetnya terlampaui.
  double get ratio => amount <= 0 ? 0 : spent / amount;

  factory BudgetItem.fromJson(Map<String, dynamic> json) => BudgetItem(
    categoryId: json['categoryId'] as String,
    name: json['name'] as String,
    icon: json['icon'] as String,
    color: json['color'] as String,
    amount: double.parse(json['amount'] as String),
    spent: double.parse(json['spent'] as String),
  );
}

enum BudgetStatus {
  safe('Budget aman'),
  tight('Budget mepet'),
  over('Lewat budget');

  const BudgetStatus(this.label);

  final String label;
}

/// Budget satu bulan WIB: angka budgetnya tetap, terpakainya per bulan.
class BudgetSummary {
  const BudgetSummary({
    required this.year,
    required this.month,
    required this.totalBudget,
    required this.totalSpent,
    required this.items,
  });

  final int year;
  final int month;
  final double totalBudget;
  final double totalSpent;
  final List<BudgetItem> items;

  bool get isEmpty => items.isEmpty;
  double get remaining => totalBudget - totalSpent;

  /// Satu kategori lewat sudah cukup buat status "lewat" — total yang masih
  /// aman bisa menyembunyikan satu pos yang jebol.
  BudgetStatus get status {
    if (items.any((i) => i.ratio > 1)) return BudgetStatus.over;
    if (items.any((i) => i.ratio >= 0.8)) return BudgetStatus.tight;
    return BudgetStatus.safe;
  }

  factory BudgetSummary.fromJson(Map<String, dynamic> json) => BudgetSummary(
    year: json['year'] as int,
    month: json['month'] as int,
    totalBudget: double.parse(json['totalBudget'] as String),
    totalSpent: double.parse(json['totalSpent'] as String),
    items: (json['items'] as List<dynamic>)
        .map((e) => BudgetItem.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
