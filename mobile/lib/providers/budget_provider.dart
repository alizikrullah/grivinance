import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/budget_model.dart';
import '../data/repositories/budget_repository.dart';
import 'auth_provider.dart';
import 'data_refresh.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(apiServiceProvider));
});

typedef BudgetMonth = ({int year, int month});

BudgetMonth currentBudgetMonth() {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
}

/// Budget satu bulan. Kuncinya record, jadi (2026, 9) dari mana pun berbagi cache.
final budgetsProvider = FutureProvider.family<BudgetSummary, BudgetMonth>((ref, month) {
  return whenSignedIn(
    ref,
    () => ref.read(budgetRepositoryProvider).month(month.year, month.month),
  );
});

/// Bulan yang lagi dilihat di layar Budget.
final budgetScreenMonthProvider = StateProvider<BudgetMonth>((ref) => currentBudgetMonth());

/// Tulis budget lewat sini supaya Beranda, layar Budget, dan misi ikut segar.
final budgetActionsProvider = Provider<BudgetActions>(BudgetActions.new);

class BudgetActions {
  BudgetActions(this._ref);

  final Ref _ref;

  Future<void> set(String categoryId, double amount) async {
    await _ref.read(budgetRepositoryProvider).set(categoryId, amount);
    invalidateMoneyData(_ref.invalidate);
  }

  Future<void> delete(String categoryId) async {
    await _ref.read(budgetRepositoryProvider).delete(categoryId);
    invalidateMoneyData(_ref.invalidate);
  }
}
