import 'category_model.dart';

class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    required this.total,
  });

  final String categoryId;
  final String name;
  final String icon;
  final String color;
  final TxType type;
  final double total;

  factory CategoryBreakdown.fromJson(Map<String, dynamic> json) => CategoryBreakdown(
        categoryId: json['categoryId'] as String,
        name: json['name'] as String,
        icon: json['icon'] as String,
        color: json['color'] as String,
        type: TxType.fromApi(json['type'] as String),
        total: double.parse(json['total'] as String),
      );
}

/// Dipakai tab Harian dan Bulanan — bentuk responsnya sama.
class PeriodSummary {
  const PeriodSummary({
    required this.totalIncome,
    required this.totalExpense,
    required this.byCategory,
  });

  final double totalIncome;
  final double totalExpense;
  final List<CategoryBreakdown> byCategory;

  List<CategoryBreakdown> get expenses =>
      byCategory.where((c) => c.type == TxType.expense).toList();

  List<CategoryBreakdown> get incomes =>
      byCategory.where((c) => c.type == TxType.income).toList();

  factory PeriodSummary.fromJson(Map<String, dynamic> json) => PeriodSummary(
        totalIncome: double.parse(json['totalIncome'] as String),
        totalExpense: double.parse(json['totalExpense'] as String),
        byCategory: (json['byCategory'] as List<dynamic>)
            .map((e) => CategoryBreakdown.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MonthBucket {
  const MonthBucket({
    required this.month,
    required this.income,
    required this.expense,
  });

  final int month;
  final double income;
  final double expense;

  factory MonthBucket.fromJson(Map<String, dynamic> json) => MonthBucket(
        month: json['month'] as int,
        income: double.parse(json['income'] as String),
        expense: double.parse(json['expense'] as String),
      );
}

class YearlySummary {
  const YearlySummary({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.months,
  });

  final int year;
  final double totalIncome;
  final double totalExpense;
  final List<MonthBucket> months;

  factory YearlySummary.fromJson(Map<String, dynamic> json) => YearlySummary(
        year: json['year'] as int,
        totalIncome: double.parse(json['totalIncome'] as String),
        totalExpense: double.parse(json['totalExpense'] as String),
        months: (json['months'] as List<dynamic>)
            .map((e) => MonthBucket.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
