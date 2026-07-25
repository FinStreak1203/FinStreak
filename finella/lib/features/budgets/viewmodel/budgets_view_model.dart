import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';

/// A budget paired with the amount spent against it this month.
class BudgetSummary {
  final Budget budget;
  final double spent;

  const BudgetSummary({required this.budget, required this.spent});

  String get categoryId => budget.categoryId;
  String get categoryName => budget.categoryName;
  double get limit => budget.limitAmount;
  double get remaining => limit - spent;
  double get progress =>
      limit > 0 ? (spent / limit).clamp(0.0, 1.0).toDouble() : 0.0;
  bool get isOverBudget => spent > limit;
}

/// Immutable view-state for the Budgets screen.
class BudgetsState {
  final DateTime month;
  final List<BudgetSummary> budgets;
  final double totalLimit;
  final double totalSpent;
  final bool isLoading;

  const BudgetsState({
    required this.month,
    this.budgets = const [],
    this.totalLimit = 0,
    this.totalSpent = 0,
    this.isLoading = true,
  });
}

/// The month currently shown on the Budgets screen.
class BudgetMonthNotifier extends StateNotifier<DateTime> {
  BudgetMonthNotifier() : super(_thisMonth());

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void previousMonth() => state = DateTime(state.year, state.month - 1);
  void nextMonth() => state = DateTime(state.year, state.month + 1);
}

final budgetMonthProvider =
    StateNotifierProvider<BudgetMonthNotifier, DateTime>(
  (ref) => BudgetMonthNotifier(),
);

/// Derived, read-only state for the selected month.
final budgetsStateProvider = Provider<BudgetsState>((ref) {
  final month = ref.watch(budgetMonthProvider);
  final budgetsAsync = ref.watch(allBudgetsProvider);
  final txnsAsync = ref.watch(allTransactionsProvider);

  final all = budgetsAsync.valueOrNull;
  if (all == null) return BudgetsState(month: month, isLoading: true);

  final txns = txnsAsync.valueOrNull ?? const <Transaction>[];
  final monthStart = DateTime(month.year, month.month, 1);
  final monthEnd = DateTime(month.year, month.month + 1, 1);

  // Spent per category id within the selected month (expenses only).
  final spentByCat = <String, double>{};
  for (final t in txns) {
    if (t.type != 'expense') continue;
    if (t.date.isBefore(monthStart) || !t.date.isBefore(monthEnd)) continue;
    spentByCat[t.categoryId] = (spentByCat[t.categoryId] ?? 0) + t.amount;
  }

  final monthBudgets = all
      .where((b) => b.year == month.year && b.month == month.month)
      .toList();

  var totalLimit = 0.0;
  var totalSpent = 0.0;
  final summaries = monthBudgets.map((b) {
    final spent = spentByCat[b.categoryId] ?? 0;
    totalLimit += b.limitAmount;
    totalSpent += spent;
    return BudgetSummary(budget: b, spent: spent);
  }).toList();

  return BudgetsState(
    month: month,
    budgets: summaries,
    totalLimit: totalLimit,
    totalSpent: totalSpent,
    isLoading: false,
  );
});

/// The 3 most recent budgets for the *current* month — for the home preview.
///
/// Independent of [budgetMonthProvider] so navigating months on the Budgets
/// screen never changes what the home screen shows.
final recentBudgetsProvider = Provider<List<BudgetSummary>>((ref) {
  final all = ref.watch(allBudgetsProvider).valueOrNull;
  if (all == null) return const [];
  final txns = ref.watch(allTransactionsProvider).valueOrNull ??
      const <Transaction>[];

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  final spentByCat = <String, double>{};
  for (final t in txns) {
    if (t.type != 'expense') continue;
    if (t.date.isBefore(monthStart) || !t.date.isBefore(monthEnd)) continue;
    spentByCat[t.categoryId] = (spentByCat[t.categoryId] ?? 0) + t.amount;
  }

  return all
      .where((b) => b.year == now.year && b.month == now.month)
      .take(3)
      .map((b) =>
          BudgetSummary(budget: b, spent: spentByCat[b.categoryId] ?? 0))
      .toList();
});

/// Commands for the Budgets screen — the write side of the view-model.
class BudgetsViewModel {
  final Ref _ref;
  BudgetsViewModel(this._ref);

  /// Adds a budget for [categoryId] in the given month, or updates the limit
  /// if one already exists for that category and month (no duplicates).
  Future<void> addBudget({
    required String categoryId,
    required String categoryName,
    required double limitAmount,
    required int year,
    required int month,
  }) async {
    final dao = _ref.read(budgetDaoProvider);
    final existing = await dao.getAllBudgets();

    Budget? match;
    for (final b in existing) {
      if (b.categoryId == categoryId && b.year == year && b.month == month) {
        match = b;
        break;
      }
    }

    if (match != null) {
      await dao.updateBudget(match.copyWith(limitAmount: limitAmount));
      return;
    }

    await dao.insertBudget(
      BudgetsCompanion(
        categoryId: Value(categoryId),
        categoryName: Value(categoryName),
        limitAmount: Value(limitAmount),
        year: Value(year),
        month: Value(month),
      ),
    );
  }

  Future<void> updateBudget(Budget budget, double limitAmount) =>
      _ref.read(budgetDaoProvider).updateBudget(
            budget.copyWith(limitAmount: limitAmount),
          );

  Future<void> deleteBudget(int id) =>
      _ref.read(budgetDaoProvider).deleteBudget(id);
}

final budgetsViewModelProvider =
    Provider<BudgetsViewModel>((ref) => BudgetsViewModel(ref));
