import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/category_options.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/category_dao.dart';
import '../../../core/providers/database_providers.dart';
import '../../transactions/presentation/category_picker_sheet.dart';
import '../models/category_stat.dart';

// ── Private accumulator ───────────────────────────────────────
class _CatAccum {
  final String name;
  final double amount;
  final int count;
  const _CatAccum(this.name, this.amount, this.count);
  _CatAccum add(double a) => _CatAccum(name, amount + a, count + 1);
}

String _fmtAmt(double amount) {
  if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
  if (amount >= 1000) {
    final s = amount.toInt().toString();
    return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
  return '₹${amount.toInt()}';
}

// ── State ─────────────────────────────────────────────────────
class InsightsState {
  final DateTime selectedMonth;
  final String selectedTab;
  final List<CategoryStat> expenseStats;
  final List<CategoryStat> incomeStats;
  final double totalExpense;
  final double totalIncome;
  final bool isLoading;
  final List<InsightCard> aiInsights;

  const InsightsState({
    required this.selectedMonth,
    this.selectedTab = 'expenses',
    this.expenseStats = const [],
    this.incomeStats = const [],
    this.totalExpense = 0,
    this.totalIncome = 0,
    this.isLoading = true,
    this.aiInsights = const [],
  });

  InsightsState copyWith({
    DateTime? selectedMonth,
    String? selectedTab,
    List<CategoryStat>? expenseStats,
    List<CategoryStat>? incomeStats,
    double? totalExpense,
    double? totalIncome,
    bool? isLoading,
    List<InsightCard>? aiInsights,
  }) {
    return InsightsState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      selectedTab: selectedTab ?? this.selectedTab,
      expenseStats: expenseStats ?? this.expenseStats,
      incomeStats: incomeStats ?? this.incomeStats,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
      isLoading: isLoading ?? this.isLoading,
      aiInsights: aiInsights ?? this.aiInsights,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────
class InsightsNotifier extends StateNotifier<InsightsState> {
  final Ref _ref;
  List<Transaction> _allTxs = [];
  Map<String, CustomCategory> _customById = const {};

  InsightsNotifier(this._ref)
      : super(InsightsState(selectedMonth: DateTime.now())) {
    _ref.listen<AsyncValue<List<Transaction>>>(
      allTransactionsProvider,
      (_, next) => next.whenData((txs) {
        _allTxs = txs;
        _compute(state.selectedMonth);
      }),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<CustomCategory>>>(
      customCategoriesProvider,
      (_, next) => next.whenData((cats) {
        _customById = {for (final c in cats) c.id: c};
        _compute(state.selectedMonth);
      }),
      fireImmediately: true,
    );
  }

  void selectTab(String tab) => state = state.copyWith(selectedTab: tab);

  void previousMonth() {
    final m = state.selectedMonth;
    final newMonth = DateTime(m.year, m.month - 1);
    state = state.copyWith(selectedMonth: newMonth, isLoading: true);
    _compute(newMonth);
  }

  void nextMonth() {
    final m = state.selectedMonth;
    final newMonth = DateTime(m.year, m.month + 1);
    state = state.copyWith(selectedMonth: newMonth, isLoading: true);
    _compute(newMonth);
  }

  void _compute(DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    final monthTxs = _allTxs
        .where((t) => !t.date.isBefore(monthStart) && t.date.isBefore(monthEnd))
        .toList();

    // ── Expense stats ──────────────────────────────────────
    final expenseMap = <String, _CatAccum>{};
    double totalExpense = 0;
    for (final t in monthTxs.where((t) => t.type == 'expense')) {
      totalExpense += t.amount;
      expenseMap[t.categoryId] = expenseMap.containsKey(t.categoryId)
          ? expenseMap[t.categoryId]!.add(t.amount)
          : _CatAccum(t.categoryName, t.amount, 1);
    }

    // ── Income stats ───────────────────────────────────────
    final incomeMap = <String, _CatAccum>{};
    double totalIncome = 0;
    for (final t in monthTxs.where((t) => t.type == 'income')) {
      totalIncome += t.amount;
      incomeMap[t.categoryId] = incomeMap.containsKey(t.categoryId)
          ? incomeMap[t.categoryId]!.add(t.amount)
          : _CatAccum(t.categoryName, t.amount, 1);
    }

    final expenseStats = _buildStats(expenseMap, totalExpense, allCategories);
    final incomeStats  = _buildStats(incomeMap,  totalIncome,  incomeCategories);
    final aiInsights = _generateInsights(
      month: month,
      monthTxs: monthTxs,
      expenseStats: expenseStats,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
    );

    state = state.copyWith(
      selectedMonth: month,
      expenseStats: expenseStats,
      incomeStats: incomeStats,
      totalExpense: totalExpense,
      totalIncome: totalIncome,
      aiInsights: aiInsights,
      isLoading: false,
    );
  }

  List<CategoryStat> _buildStats(
      Map<String, _CatAccum> map, double total, List<CategoryItem> categories) {
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.amount.compareTo(a.value.amount));

    return sorted.map((e) {
      // Resolve the display name/icon/colour from the category id — NOT the
      // transaction's stored categoryName, which for imported-but-unclassified
      // rows is a parser label like "Credit Card Purchase" / "UPI Debit".
      CategoryItem? catItem;
      for (final c in categories) {
        if (c.id == e.key) {
          catItem = c;
          break;
        }
      }
      final custom = _customById[e.key];

      final String name;
      final Color color;
      final Color bgColor;
      final IconData icon;
      if (catItem != null) {
        name = catItem.name;
        color = catItem.iconColor;
        bgColor = catItem.bgColor;
        icon = catItem.icon;
      } else if (custom != null) {
        name = custom.name;
        color = categoryColorFor(custom.colorKey).fg;
        bgColor = categoryColorFor(custom.colorKey).bg;
        icon = categoryIconFor(custom.iconKey);
      } else {
        // Unknown / 'other' bucket — never surface a parser label.
        name = 'Other';
        color = const Color(0xFF6B7280);
        bgColor = const Color(0xFFF3F4F6);
        icon = Icons.more_horiz_rounded;
      }

      return CategoryStat(
        categoryId: e.key,
        name: name,
        color: color,
        bgColor: bgColor,
        icon: icon,
        amount: e.value.amount,
        transactionCount: e.value.count,
        percentage: total > 0 ? e.value.amount / total * 100 : 0,
      );
    }).toList();
  }

  List<InsightCard> _generateInsights({
    required DateTime month,
    required List<Transaction> monthTxs,
    required List<CategoryStat> expenseStats,
    required double totalExpense,
    required double totalIncome,
  }) {
    final insights = <InsightCard>[];
    final now = DateTime.now();
    final isCurrentMonth =
        now.year == month.year && now.month == month.month;

    // ── Pattern: top category ─────────────────────────────
    if (expenseStats.isNotEmpty) {
      final top = expenseStats.first;
      insights.add(InsightCard(
        title: 'Top Spending: ${top.name}',
        body:
            '${top.percentage.toInt()}% of expenses (${_fmtAmt(top.amount)}) — ${top.transactionCount} transactions',
        type: InsightCardType.pattern,
      ));
    } else {
      insights.add(const InsightCard(
        title: 'No Patterns Yet',
        body: 'Add expense transactions to see spending patterns',
        type: InsightCardType.pattern,
      ));
    }

    // ── Forecast: project month-end spend ─────────────────
    if (isCurrentMonth && monthTxs.isNotEmpty && totalExpense > 0) {
      final daysElapsed = now.day.clamp(1, 31);
      final daysInMonth =
          DateTime(month.year, month.month + 1, 0).day;
      final daysRemaining = daysInMonth - daysElapsed;
      final dailyAvg = totalExpense / daysElapsed;
      final projected = totalExpense + dailyAvg * daysRemaining;
      insights.add(InsightCard(
        title: 'Spending Forecast',
        body:
            'At current pace, month-end total: ${_fmtAmt(projected)} (avg ${_fmtAmt(dailyAvg)}/day)',
        type: InsightCardType.forecast,
      ));
    } else {
      insights.add(InsightCard(
        title: 'Spending Forecast',
        body: totalExpense > 0
            ? 'Total spending this month: ${_fmtAmt(totalExpense)}'
            : 'No spending data for this period',
        type: InsightCardType.forecast,
      ));
    }

    // ── Behavior: savings rate ────────────────────────────
    if (totalIncome > 0) {
      final savings = totalIncome - totalExpense;
      final rate = (savings / totalIncome * 100).round().abs();
      if (savings >= 0) {
        insights.add(InsightCard(
          title: 'Savings Rate: $rate%',
          body:
              'You saved ${_fmtAmt(savings)} of ${_fmtAmt(totalIncome)} income this month',
          type: InsightCardType.behavior,
        ));
      } else {
        insights.add(InsightCard(
          title: 'Overspending Alert',
          body:
              'Expenses exceed income by ${_fmtAmt(-savings)} this month — consider cutting back',
          type: InsightCardType.behavior,
        ));
      }
    } else if (expenseStats.isNotEmpty) {
      insights.add(const InsightCard(
        title: 'Income Missing',
        body: 'Add income transactions to calculate your savings rate',
        type: InsightCardType.behavior,
      ));
    } else {
      insights.add(const InsightCard(
        title: 'Behavior Analysis',
        body: 'Start logging transactions to unlock behavior insights',
        type: InsightCardType.behavior,
      ));
    }

    // ── Smart saving: reduce top category ────────────────
    if (expenseStats.isNotEmpty) {
      final top = expenseStats.first;
      final saving = top.amount * 0.2;
      insights.add(InsightCard(
        title: 'Smart Saving',
        body:
            'Cut ${top.name} by 20% to save ${_fmtAmt(saving)} — that\'s ${_fmtAmt(saving * 12)} per year',
        type: InsightCardType.saving,
      ));
    } else {
      insights.add(const InsightCard(
        title: 'Smart Saving',
        body: 'Log expenses to get personalized saving recommendations',
        type: InsightCardType.saving,
      ));
    }

    return insights;
  }
}

final insightsProvider =
    StateNotifierProvider<InsightsNotifier, InsightsState>(
  (ref) => InsightsNotifier(ref),
);
