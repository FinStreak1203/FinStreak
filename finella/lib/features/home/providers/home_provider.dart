import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/models/app_models.dart';
import '../../../core/providers/database_providers.dart';
import '../../transactions/presentation/category_picker_sheet.dart';

class HomeState {
  final DateTime selectedMonth;
  final double balance;
  final double totalIncome;
  final double totalExpense;
  final double dailyChange;
  final int streakDays;
  final int currentStreak;
  final int billsDueCount;
  final double billsDueAmount;
  final double weeklyTotal;
  final List<SpendingCategory> weeklySpending;
  final List<TransactionData> recentTransactions;
  final List<GoalData> goals;
  final double savedAmount;
  final List<AiInsight> aiInsights;
  final int aiScore;
  final String prediction;
  final bool isLoading;

  const HomeState({
    required this.selectedMonth,
    this.balance = 0,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.dailyChange = 0,
    this.streakDays = 0,
    this.currentStreak = 0,
    this.billsDueCount = 0,
    this.billsDueAmount = 0,
    this.weeklyTotal = 0,
    this.weeklySpending = const [],
    this.recentTransactions = const [],
    this.goals = const [],
    this.savedAmount = 0,
    this.aiInsights = const [],
    this.aiScore = 82,
    this.prediction = '',
    this.isLoading = true,
  });

  HomeState copyWith({
    DateTime? selectedMonth,
    double? balance,
    double? totalIncome,
    double? totalExpense,
    double? dailyChange,
    int? streakDays,
    int? currentStreak,
    int? billsDueCount,
    double? billsDueAmount,
    double? weeklyTotal,
    List<SpendingCategory>? weeklySpending,
    List<TransactionData>? recentTransactions,
    List<GoalData>? goals,
    double? savedAmount,
    List<AiInsight>? aiInsights,
    int? aiScore,
    String? prediction,
    bool? isLoading,
  }) {
    return HomeState(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      balance: balance ?? this.balance,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpense: totalExpense ?? this.totalExpense,
      dailyChange: dailyChange ?? this.dailyChange,
      streakDays: streakDays ?? this.streakDays,
      currentStreak: currentStreak ?? this.currentStreak,
      billsDueCount: billsDueCount ?? this.billsDueCount,
      billsDueAmount: billsDueAmount ?? this.billsDueAmount,
      weeklyTotal: weeklyTotal ?? this.weeklyTotal,
      weeklySpending: weeklySpending ?? this.weeklySpending,
      recentTransactions: recentTransactions ?? this.recentTransactions,
      goals: goals ?? this.goals,
      savedAmount: savedAmount ?? this.savedAmount,
      aiInsights: aiInsights ?? this.aiInsights,
      aiScore: aiScore ?? this.aiScore,
      prediction: prediction ?? this.prediction,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final Ref _ref;

  // Cached raw data so we can re-filter when month changes
  List<Transaction> _allTxs = [];
  List<Goal> _allGoals = [];

  HomeNotifier(this._ref) : super(HomeState(selectedMonth: DateTime.now())) {
    _ref.listen<AsyncValue<List<Transaction>>>(
      allTransactionsProvider,
      (_, next) => next.whenData((txs) {
        _allTxs = txs;
        _compute(txs: txs, dbGoals: _allGoals, month: state.selectedMonth);
      }),
      fireImmediately: true,
    );
    _ref.listen<AsyncValue<List<Goal>>>(
      allGoalsProvider,
      (_, next) => next.whenData((goals) {
        _allGoals = goals;
        _compute(txs: _allTxs, dbGoals: goals, month: state.selectedMonth);
      }),
      fireImmediately: true,
    );
  }

  void _compute({
    required List<Transaction> txs,
    required List<Goal> dbGoals,
    required DateTime month,
  }) {
    // Monthly income / expense
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);
    double totalIncome = 0, totalExpense = 0;
    for (final t in txs) {
      if (t.date.isBefore(monthStart) || !t.date.isBefore(monthEnd)) continue;
      if (t.type == 'income') totalIncome += t.amount;
      if (t.type == 'expense') totalExpense += t.amount;
    }

    // All-time balance
    double allIncome = 0, allExpense = 0;
    for (final t in txs) {
      if (t.type == 'income') allIncome += t.amount;
      if (t.type == 'expense') allExpense += t.amount;
    }

    // Streak
    final streak = _computeStreak(txs);

    // Recent 5 — show only the transfer_out side of transfers (hide _in)
    final transferDest = <String, String>{};
    for (final t in txs) {
      if (t.type == 'transfer_in' && t.transferRef != null) {
        transferDest[t.transferRef!] = t.accountName;
      }
    }
    final recent = txs
        .where((t) => t.type != 'transfer_in')
        .take(5)
        .map((t) => _toTransactionData(t, transferDest))
        .toList();

    // Weekly spending
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekExpenses = txs
        .where((t) => t.type == 'expense' && t.date.isAfter(weekAgo))
        .toList();
    final weeklyTotal =
        weekExpenses.fold(0.0, (s, t) => s + t.amount);
    final weeklySpending = _weeklySpending(weekExpenses, weeklyTotal);

    // Goals
    final goalData = dbGoals
        .map((g) => GoalData(
              id: g.id.toString(),
              name: g.name,
              saved: g.savedAmount,
              target: g.targetAmount,
            ))
        .toList();
    final savedAmount = dbGoals.fold(0.0, (s, g) => s + g.savedAmount);

    state = state.copyWith(
      selectedMonth: month,
      balance: allIncome - allExpense,
      totalIncome: totalIncome,
      totalExpense: totalExpense,
      dailyChange: 0,
      streakDays: streak,
      currentStreak: streak,
      billsDueCount: 0,
      billsDueAmount: 0,
      weeklyTotal: weeklyTotal,
      weeklySpending: weeklySpending,
      recentTransactions: recent,
      goals: goalData,
      savedAmount: savedAmount,
      aiScore: 82,
      prediction: 'On track for this month',
      aiInsights: const [
        AiInsight(
            type: InsightType.warn,
            title: 'Food delivery up 40% this week',
            body: 'Cook 3 meals to save ₹2,500'),
        AiInsight(
            type: InsightType.save,
            title: 'Cancel Hotstar + switch Spotify',
            body: 'Save ₹5,188/year combined'),
        AiInsight(
            type: InsightType.goal,
            title: 'Emergency Fund hits Gold milestone',
            body: 'At current pace — just 6 weeks!'),
      ],
      isLoading: false,
    );
  }

  int _computeStreak(List<Transaction> txs) {
    if (txs.isEmpty) return 0;
    final txDates = txs
        .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
        .toSet();
    int streak = 0;
    var check = DateTime.now();
    check = DateTime(check.year, check.month, check.day);
    while (txDates.contains(check)) {
      streak++;
      check = check.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<SpendingCategory> _weeklySpending(
      List<Transaction> expenses, double total) {
    if (expenses.isEmpty) return [];
    final catMap = <String, double>{};
    final catNameMap = <String, String>{};
    for (final t in expenses) {
      catMap[t.categoryId] = (catMap[t.categoryId] ?? 0) + t.amount;
      catNameMap[t.categoryId] = t.categoryName;
    }
    final sorted = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    const colors = [
      Color(0xFFEF4444),
      Color(0xFF3B82F6),
      Color(0xFF8B5CF6),
      Color(0xFF6B7280),
    ];
    final result = <SpendingCategory>[];
    for (int i = 0; i < sorted.length && i < 4; i++) {
      final e = sorted[i];
      final pct = total > 0 ? (e.value / total * 100).round() : 0;
      result.add(SpendingCategory(
        name: catNameMap[e.key] ?? e.key,
        amount: e.value,
        color: i < colors.length ? colors[i] : colors.last,
        percentage: pct,
      ));
    }
    return result;
  }

  TransactionData _toTransactionData(
      Transaction t, Map<String, String> transferDest) {
    if (t.type == 'transfer_out') {
      return TransactionData(
        id: t.id.toString(),
        name: 'Transfer',
        category: 'Transfer',
        accountName: t.accountName,
        amount: t.amount,
        isExpense: false,
        date: t.date,
        categoryColor: const Color(0xFF1565C0),
        categoryIcon: Icons.swap_horiz_rounded,
        isTransfer: true,
        transferTo: t.transferRef != null ? transferDest[t.transferRef!] : null,
      );
    }

    Color color = const Color(0xFF6B7280);
    IconData icon = Icons.more_horiz_rounded;

    final categories =
        t.type == 'income' ? incomeCategories : allCategories;

    for (final cat in categories) {
      if (cat.id == t.categoryId) {
        color = cat.iconColor;
        icon  = cat.icon;
        break;
      }
    }

    // Income fallback when categoryId not found in incomeCategories
    if (t.type == 'income' && icon == Icons.more_horiz_rounded) {
      color = const Color(0xFF22C55E);
      icon  = Icons.account_balance_rounded;
    }

    return TransactionData(
      id: t.id.toString(),
      name: t.payee.isNotEmpty ? t.payee : t.categoryName,
      category: t.categoryName,
      accountName: t.accountName,
      amount: t.amount,
      isExpense: t.type == 'expense',
      date: t.date,
      categoryColor: color,
      categoryIcon: icon,
    );
  }

  Future<void> loadHomeData(DateTime month) async {
    state = state.copyWith(selectedMonth: month, isLoading: true);
    _compute(txs: _allTxs, dbGoals: _allGoals, month: month);
  }

  void previousMonth() {
    final m = state.selectedMonth;
    loadHomeData(DateTime(m.year, m.month - 1));
  }

  void nextMonth() {
    final m = state.selectedMonth;
    loadHomeData(DateTime(m.year, m.month + 1));
  }
}

final homeProvider =
    StateNotifierProvider<HomeNotifier, HomeState>((ref) => HomeNotifier(ref));
