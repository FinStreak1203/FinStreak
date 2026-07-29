import '../../../core/database/app_database.dart';
import '../../../core/services/streak_service.dart';
import '../models/finsco_score.dart';

class FinScoreCalculator {
  static const double performanceTarget = 60;
  static const double rawPerformanceTarget = 70;

static FinScoreResult calculate({
    required List<Transaction> transactions,
    required List<Account> accounts,
    required List<Budget> budgets,
    required List<Goal> goals,
    required List<Loan> loans,
    required List<BudgetReview> budgetReviews,
    required List<GoalContribution> goalContributions,
    required List<LearningProgressesData> learningProgress,
    required StreakData streak,
    required DateTime now,
  }) {
    final windowStart = DateTime(now.year, now.month - 5, 1);
    final recentTxs = transactions
        .where((t) => !t.date.isBefore(windowStart) && !t.date.isAfter(now))
        .toList();

    final activeLoans = loans.where((l) => l.isActive).toList();
    final creditCards = accounts.where((a) => a.type == 'credit_card').toList();

    final components = [
      _incomeStability(recentTxs, now),
      _savingsDiscipline(recentTxs, now),
      _expenseDiscipline(recentTxs, now),
      _budgetDiscipline(recentTxs, budgets, now, budgetReviews),
      _debtManagement(recentTxs, accounts, transactions, now, activeLoans, creditCards),
      _emergencyFund(recentTxs, accounts, transactions, now),
      _investmentHabit(recentTxs, accounts, now),
      _finstreakConsistency(streak, now),
      _financialGoals(goals, goalContributions),
      _financialLearning(learningProgress),
    ];

    final foundation = components.fold<double>(
      0,
      (sum, c) => sum + c.foundationScore,
    );
    final rawPerformance = components.fold<double>(
      0,
      (sum, c) => sum + c.earnedPerformanceScore,
    );
    final earnedPerformance =
        (rawPerformance / rawPerformanceTarget) * performanceTarget;
    final score = (foundation + earnedPerformance)
        .round()
        .clamp(0, 100)
        .toInt();

    return FinScoreResult(
      score: score,
      foundationScore: foundation,
      earnedPerformanceScore: _clampDouble(
        earnedPerformance,
        0,
        performanceTarget,
      ),
      rawPerformanceScore: _clampDouble(
        rawPerformance,
        0,
        rawPerformanceTarget,
      ),
      maxRawPerformanceScore: rawPerformanceTarget,
      components: components,
    );
  }

  static FinScoreComponent _component(
    FinScoreCategory category, {
    required double earned,
    required bool applicable,
    required String summary,
    required String recommendation,
  }) {
    return FinScoreComponent(
      category: category,
      foundationScore: category.foundationScore,
      maxPerformanceScore: category.performanceScore,
      earnedPerformanceScore: applicable
          ? _clampDouble(earned, 0, category.performanceScore)
          : 0.0,
      isApplicable: applicable,
      summary: summary,
      recommendation: recommendation,
    );
  }

  static FinScoreComponent _incomeStability(
    List<Transaction> txs,
    DateTime now,
  ) {
    final incomeByMonth = _monthlyTotals(txs, now, (t) => t.type == 'income');
    final incomeMonths = incomeByMonth.where((v) => v > 0).length;
    final totalIncome = incomeByMonth.fold<double>(0, (s, v) => s + v);
    if (totalIncome <= 0) {
      return _component(
        FinScoreCategory.incomeStability,
        applicable: true,
        earned: 0,
        summary: 'No income has been logged in the last six months.',
        recommendation: 'Add salary, business, freelance or other income.',
      );
    }

    final activeValues = incomeByMonth.where((v) => v > 0).toList();
    final avg =
        activeValues.fold<double>(0, (s, v) => s + v) / activeValues.length;
    final variance =
        activeValues.fold<double>(0, (s, v) => s + ((v - avg) * (v - avg))) /
        activeValues.length;
    final volatility = avg <= 0
        ? 1.0
        : _clampDouble(_sqrt(variance) / avg, 0, 1);
    final consistencyScore = 1 - volatility;
    final monthScore = incomeMonths / 6;
    final sources = txs
        .where((t) => t.type == 'income')
        .map((t) => t.categoryId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;
    final diversityScore = _clampDouble(sources / 3, 0, 1);
    final earned =
        FinScoreCategory.incomeStability.performanceScore *
        ((consistencyScore * 0.65) +
            (monthScore * 0.2) +
            (diversityScore * 0.15));

    return _component(
      FinScoreCategory.incomeStability,
      applicable: true,
      earned: earned,
      summary:
          'Income was recorded in $incomeMonths of the last 6 months with ${sources.clamp(1, 99)} source${sources == 1 ? '' : 's'}.',
      recommendation: incomeMonths >= 6 && volatility <= 0.25
          ? 'Keep income regular and continue tracking every credit.'
          : 'Track all income and build predictable monthly inflows.',
    );
  }

  static FinScoreComponent _savingsDiscipline(
    List<Transaction> txs,
    DateTime now,
  ) {
    final incomeByMonth = _monthlyTotals(txs, now, (t) => t.type == 'income');
    final expenseByMonth = _monthlyTotals(txs, now, (t) => t.type == 'expense');
    final totalIncome = incomeByMonth.fold<double>(0, (s, v) => s + v);
    if (totalIncome <= 0) {
      return _component(
        FinScoreCategory.savingsDiscipline,
        applicable: false,
        earned: 0,
        summary: 'Savings discipline activates after income is logged.',
        recommendation:
            'Log income first so Finella can calculate savings rate.',
      );
    }

    var positiveMonths = 0;
    var incomeMonths = 0;
    var totalSavings = 0.0;
    for (var i = 0; i < incomeByMonth.length; i++) {
      if (incomeByMonth[i] <= 0) continue;
      incomeMonths++;
      final savings = incomeByMonth[i] - expenseByMonth[i];
      totalSavings += savings;
      if (savings > 0) positiveMonths++;
    }
    final rate = totalSavings / totalIncome;
    final rateScore = _thresholdScore(rate, const [
      (0.30, 1.0),
      (0.20, 0.8),
      (0.10, 0.5),
      (0.00, 0.25),
    ]);
    final consistency = incomeMonths == 0 ? 0.0 : positiveMonths / incomeMonths;
    final earned =
        FinScoreCategory.savingsDiscipline.performanceScore *
        ((rateScore * 0.7) + (consistency * 0.3));

    return _component(
      FinScoreCategory.savingsDiscipline,
      applicable: true,
      earned: earned,
      summary:
          'Savings rate is ${_pct(rate)} across the last 6 months, positive in $positiveMonths month${positiveMonths == 1 ? '' : 's'}.',
      recommendation: rate >= 0.2
          ? 'Maintain this savings rhythm and automate transfers where possible.'
          : 'Aim to save at least 20% of monthly income.',
    );
  }

  static FinScoreComponent _expenseDiscipline(
    List<Transaction> txs,
    DateTime now,
  ) {
    final expenseTxs = txs.where((t) => t.type == 'expense').toList();
    if (expenseTxs.isEmpty) {
      return _component(
        FinScoreCategory.expenseDiscipline,
        applicable: false,
        earned: 0,
        summary: 'Expense discipline activates after expenses are logged.',
        recommendation: 'Import SMS/email alerts or add expenses manually.',
      );
    }

    final income = txs
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final expense = expenseTxs.fold<double>(0, (s, t) => s + t.amount);
    final discretionary = expenseTxs
        .where((t) => _wantCategoryIds.contains(t.categoryId))
        .fold<double>(0, (s, t) => s + t.amount);
    final wantRatio = expense <= 0 ? 0.0 : discretionary / expense;
    final spendRatio = income <= 0 ? null : expense / income;
    final controlScore = spendRatio == null
        ? 1 - wantRatio
        : _clampDouble(1 - ((spendRatio - 0.65) / 0.75), 0, 1);
    final needWantScore = _clampDouble(1 - (wantRatio / 0.55), 0, 1);
    final trendScore = _expenseTrendScore(txs, now);
    final earned =
        FinScoreCategory.expenseDiscipline.performanceScore *
        ((controlScore * 0.45) + (needWantScore * 0.35) + (trendScore * 0.2));

    return _component(
      FinScoreCategory.expenseDiscipline,
      applicable: true,
      earned: earned,
      summary:
          'Discretionary spending is ${_pct(wantRatio)} of expenses${spendRatio == null ? '.' : ', with expenses at ${_pct(spendRatio)} of income.'}',
      recommendation:
          wantRatio <= 0.30 && (spendRatio == null || spendRatio <= 0.80)
          ? 'Spending mix looks controlled. Keep reviewing high-value merchants.'
          : 'Reduce shopping, entertainment, cafe and travel spends first.',
    );
  }

  static FinScoreComponent _budgetDiscipline(
    List<Transaction> txs,
    List<Budget> budgets,
    DateTime now,
    List<BudgetReview> budgetReviews,
  ) {
    final monthBudgets = budgets
        .where((b) => b.year == now.year && b.month == now.month)
        .toList();
    if (monthBudgets.isEmpty) {
      return _component(
        FinScoreCategory.budgetDiscipline,
        applicable: false,
        earned: 0,
        summary: 'No active monthly budgets are set.',
        recommendation: 'Create category budgets for this month.',
      );
    }

    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final spentByCat = <String, double>{};
    for (final t in txs) {
      if (t.type != 'expense') continue;
      if (t.date.isBefore(monthStart) || !t.date.isBefore(monthEnd)) continue;
      spentByCat[t.categoryId] = (spentByCat[t.categoryId] ?? 0) + t.amount;
    }
    var followed = 0;
    var totalLimit = 0.0;
    var totalSpent = 0.0;
    for (final budget in monthBudgets) {
      final spent = spentByCat[budget.categoryId] ?? 0;
      totalLimit += budget.limitAmount;
      totalSpent += spent;
      if (spent <= budget.limitAmount) followed++;
    }

    // Budget reviews score (how often user reviews budgets)
    final reviewsThisMonth = budgetReviews
        .where((r) => r.year == now.year && r.month == now.month)
        .length;
    final reviewScore = _clampDouble(reviewsThisMonth / monthBudgets.length, 0, 1);

    final creationScore = _clampDouble(monthBudgets.length / 4, 0, 1);
    final adherenceScore = monthBudgets.isEmpty
        ? 0.0
        : followed / monthBudgets.length;
    final totalScore = totalLimit <= 0
        ? 0.0
        : _clampDouble(1 - ((totalSpent - totalLimit) / totalLimit), 0, 1);
    final earned =
        FinScoreCategory.budgetDiscipline.performanceScore *
        ((creationScore * 0.25) +
            (adherenceScore * 0.45) +
            (totalScore * 0.2) +
            (reviewScore * 0.1));

    return _component(
      FinScoreCategory.budgetDiscipline,
      applicable: true,
      earned: earned,
      summary:
          '$followed of ${monthBudgets.length} budget${monthBudgets.length == 1 ? '' : 's'} are within limit this month. $reviewsThisMonth review${reviewsThisMonth == 1 ? '' : 's'} completed.',
      recommendation: totalSpent <= totalLimit
          ? 'Keep reviewing budgets before month-end.'
          : 'Move overspent categories back under their monthly limit.',
    );
  }

  static FinScoreComponent _debtManagement(
    List<Transaction> txs,
    List<Account> accounts,
    List<Transaction> allTxs,
    DateTime now,
    List<Loan> activeLoans,
    List<Account> creditCards,
  ) {
    final debtTxs = txs.where(_isDebtTransaction).toList();

    // Check if user has active loans
    final hasLoans = activeLoans.isNotEmpty;
    final hasCreditCards = creditCards.isNotEmpty;

    if (!hasLoans && !hasCreditCards && debtTxs.isEmpty) {
      return _component(
        FinScoreCategory.debtManagement,
        applicable: false,
        earned: 0,
        summary: 'No debt or credit products are being tracked.',
        recommendation: 'Add loans or credit cards if you use them.',
      );
    }

    final incomeByMonth = _monthlyTotals(txs, now, (t) => t.type == 'income');
    final debtByMonth = _monthlyTotals(txs, now, _isDebtTransaction);
    final monthlyIncome = _averagePositive(incomeByMonth);
    final monthlyDebt = debtByMonth.fold<double>(0, (s, v) => s + v) / 6;
    final emiRatio = monthlyIncome <= 0 ? 1.0 : monthlyDebt / monthlyIncome;

    final liabilities = creditCards.fold<double>(
      0,
      (s, a) => s + _accountCurrentBalance(a, allTxs),
    );
    final creditPressure = monthlyIncome <= 0
        ? 1.0
        : liabilities / monthlyIncome;

    // EMI repayment behavior score - use loan data if available
    double repaymentScore = 1.0;
    if (activeLoans.isNotEmpty) {
      // Score based on remaining months vs total tenure
      for (final loan in activeLoans) {
        if (loan.tenureMonths > 0) {
          final progress = 1 - (loan.remainingMonths / loan.tenureMonths);
          repaymentScore = _clampDouble(progress, 0, 1);
        }
      }
    }

    // Also consider loan repayment (outstanding vs principal)
    double loanHealthScore = 1.0;
    if (activeLoans.isNotEmpty) {
      final totalPrincipal = activeLoans.fold<double>(0, (s, l) => s + l.principalAmount);
      final totalOutstanding = activeLoans.fold<double>(0, (s, l) => s + l.outstandingAmount);
      if (totalPrincipal > 0) {
        loanHealthScore = _clampDouble(1 - (totalOutstanding / totalPrincipal) * 0.5, 0, 1);
      }
    }

    final emiScore = _clampDouble(1 - ((emiRatio - 0.15) / 0.35), 0, 1);
    final utilizationScore = _clampDouble(
      1 - ((creditPressure - 0.30) / 1.20),
      0,
      1,
    );
    final earned =
        FinScoreCategory.debtManagement.performanceScore *
        ((emiScore * 0.4) + (utilizationScore * 0.25) + (repaymentScore * 0.2) + (loanHealthScore * 0.15));

    return _component(
      FinScoreCategory.debtManagement,
      applicable: true,
      earned: earned,
      summary: 'Debt payments are about ${_pct(emiRatio)} of average income. ${activeLoans.length} active loan${activeLoans.length == 1 ? '' : 's'}.',
      recommendation: emiRatio <= 0.20 && creditPressure <= 0.30 && repaymentScore >= 0.9
          ? 'Debt load looks manageable. Keep repayments on time.'
          : 'Reduce EMI burden and keep credit utilisation below 30%.',
    );
  }

  static FinScoreComponent _emergencyFund(
    List<Transaction> txs,
    List<Account> accounts,
    List<Transaction> allTxs,
    DateTime now,
  ) {
    final emergencyAccounts = accounts.where((a) {
      final n = a.name.toLowerCase();
      return n.contains('emergency') || n.contains('rainy');
    }).toList();
    if (emergencyAccounts.isEmpty) {
      return _component(
        FinScoreCategory.emergencyFund,
        applicable: false,
        earned: 0,
        summary: 'No emergency fund account is marked yet.',
        recommendation:
            'Create an account named Emergency Fund to track runway.',
      );
    }

    final balance = emergencyAccounts.fold<double>(
      0,
      (s, a) => s + _accountCurrentBalance(a, allTxs),
    );
    final monthlyExpenses = _averagePositive(
      _monthlyTotals(txs, now, (t) => t.type == 'expense'),
    );
    final coverage = monthlyExpenses <= 0 ? 0.0 : balance / monthlyExpenses;
    final earned =
        FinScoreCategory.emergencyFund.performanceScore *
        _clampDouble(coverage / 6, 0, 1);

    return _component(
      FinScoreCategory.emergencyFund,
      applicable: true,
      earned: earned,
      summary:
          'Emergency fund covers ${coverage.toStringAsFixed(1)} month${coverage == 1 ? '' : 's'} of expenses.',
      recommendation: coverage >= 6
          ? 'You have strong resilience. Revisit the fund as expenses change.'
          : 'Build emergency savings toward six months of expenses.',
    );
  }

  static FinScoreComponent _investmentHabit(
    List<Transaction> txs,
    List<Account> accounts,
    DateTime now,
  ) {
    final investmentAccounts = accounts.where((a) {
      final n = a.name.toLowerCase();
      return n.contains('investment') ||
          n.contains('mutual') ||
          n.contains('stock') ||
          n.contains('sip') ||
          n.contains('ppf') ||
          n.contains('nps') ||
          n.contains('gold');
    }).toList();
    final investmentTxs = txs.where(_isInvestmentTransaction).toList();
    if (investmentAccounts.isEmpty && investmentTxs.isEmpty) {
      return _component(
        FinScoreCategory.investmentHabit,
        applicable: false,
        earned: 0,
        summary: 'No investment activity is being tracked yet.',
        recommendation: 'Start logging SIPs, mutual funds, stocks, PPF or NPS.',
      );
    }

    final income = txs
        .where((t) => t.type == 'income')
        .fold<double>(0, (s, t) => s + t.amount);
    final invested = investmentTxs.fold<double>(0, (s, t) => s + t.amount);
    final investRate = income <= 0 ? 0.0 : invested / income;
    final activeMonths = _monthlyTotals(
      txs,
      now,
      _isInvestmentTransaction,
    ).where((v) => v > 0).length;
    final diversification = _clampDouble(investmentAccounts.length / 3, 0, 1);
    final earned =
        FinScoreCategory.investmentHabit.performanceScore *
        ((_clampDouble(investRate / 0.20, 0, 1) * 0.45) +
            ((activeMonths / 6) * 0.35) +
            (diversification * 0.20));

    return _component(
      FinScoreCategory.investmentHabit,
      applicable: true,
      earned: earned,
      summary:
          'Investment activity appears in $activeMonths of the last 6 months.',
      recommendation: activeMonths >= 6 && investRate >= 0.15
          ? 'Stay consistent and diversify across long-term instruments.'
          : 'Set a recurring monthly SIP or investment contribution.',
    );
  }

  static FinScoreComponent _finstreakConsistency(
    StreakData streak,
    DateTime now,
  ) {
    final recentDays = List.generate(30, (i) {
      final d = now.subtract(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    }).toSet();
    final reconciled = streak.openedDates
        .map((d) => DateTime(d.year, d.month, d.day))
        .where(recentDays.contains)
        .toSet()
        .length;
    final recentConsistency = reconciled / 30;
    final streakScore = _clampDouble(streak.currentStreak / 30, 0, 1);
    final lifetimeScore = _clampDouble(
      streak.totalDays / StreakData.goal,
      0,
      1,
    );
    final earned =
        FinScoreCategory.finstreakConsistency.performanceScore *
        ((recentConsistency * 0.45) +
            (streakScore * 0.35) +
            (lifetimeScore * 0.20));

    return _component(
      FinScoreCategory.finstreakConsistency,
      applicable: true,
      earned: earned,
      summary:
          'You reconciled $reconciled of the last 30 days; current streak is ${streak.currentStreak}.',
      recommendation: reconciled >= 24
          ? 'Great consistency. Keep the daily reconcile habit alive.'
          : 'Reconcile daily and complete weekly reviews to lift FINSCO.',
    );
  }

static FinScoreComponent _financialGoals(
    List<Goal> goals, List<GoalContribution> goalContributions) {
    if (goals.isEmpty) {
      return _component(
        FinScoreCategory.financialGoals,
        applicable: false,
        earned: 0,
        summary: 'No financial goals have been created yet.',
        recommendation: 'Create at least one goal with a target amount.',
      );
    }

    final validGoals = goals.where((g) => g.targetAmount > 0).toList();
    final avgProgress = validGoals.isEmpty
        ? 0.0
        : validGoals
                    .map(
                      (g) => _clampDouble(g.savedAmount / g.targetAmount, 0, 1),
                    )
                    .fold<double>(0, (s, v) => s + v) /
                validGoals.length;
    final activeScore = _clampDouble(validGoals.length / 3, 0, 1);

    // Contribution frequency score
    double contributionScore = 0.0;
    if (goalContributions.isNotEmpty) {
      // Check how many goals have recent contributions (last 3 months)
      final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
      final goalsWithRecentContributions = <int>{};
      for (final c in goalContributions) {
        if (c.contributedAt.isAfter(threeMonthsAgo)) {
          goalsWithRecentContributions.add(c.goalId);
        }
      }
      contributionScore = validGoals.isEmpty
          ? 0.0
          : _clampDouble(goalsWithRecentContributions.length / validGoals.length, 0, 1);
    }

    final earned =
        FinScoreCategory.financialGoals.performanceScore *
        ((activeScore * 0.25) + (avgProgress * 0.5) + (contributionScore * 0.25));

    return _component(
      FinScoreCategory.financialGoals,
      applicable: true,
      earned: earned,
      summary:
          '${validGoals.length} goal${validGoals.length == 1 ? '' : 's'} tracked with ${_pct(avgProgress)} average progress.',
      recommendation: avgProgress >= 0.6
          ? 'Goal progress is strong. Keep contributions regular.'
          : 'Add recurring contributions toward your top goal.',
    );
  }

  static FinScoreComponent _financialLearning(
    List<LearningProgressesData> learningProgress) {
    if (learningProgress.isEmpty) {
      return _component(
        FinScoreCategory.financialLearning,
        applicable: true,
        earned: 0,
        summary: 'No learning activity recorded yet.',
        recommendation: 'Complete a financial lesson to start earning points.',
      );
    }

    final completed = learningProgress.where((p) => p.completed).toList();
    final totalCompleted = completed.length;
    final totalXp = completed.fold<double>(0, (s, p) => s + ((p.score as num?)?.toDouble() ?? 10.0));
    final avgScore = completed.isEmpty
        ? 0.0
        : completed
            .map((p) => (p.score as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a + b) /
            completed.length;

    // Score based on: completion count, average quiz score
    final completionScore = _clampDouble(totalCompleted / 10, 0, 1); // 10 completed = max
    final quizScore = _clampDouble(avgScore / 100, 0, 1); // Assuming score is 0-100

    final earned =
        FinScoreCategory.financialLearning.performanceScore *
        ((completionScore * 0.6) + (quizScore * 0.4));

    return _component(
      FinScoreCategory.financialLearning,
      applicable: true,
      earned: earned,
      summary:
          '$totalCompleted lesson${totalCompleted == 1 ? '' : 's'} completed. Average score: ${avgScore.toStringAsFixed(0)}%.',
      recommendation: totalCompleted >= 5 && avgScore >= 70
          ? 'Excellent learning streak! Explore advanced topics.'
          : 'Complete more lessons and aim for higher quiz scores.',
    );
  }

  static List<double> _monthlyTotals(
    List<Transaction> txs,
    DateTime now,
    bool Function(Transaction t) include,
  ) {
    return [
      for (var i = 5; i >= 0; i--)
        _monthTotal(txs, DateTime(now.year, now.month - i, 1), include),
    ];
  }

  static double _monthTotal(
    List<Transaction> txs,
    DateTime month,
    bool Function(Transaction t) include,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    return txs
        .where(
          (t) => include(t) && !t.date.isBefore(start) && t.date.isBefore(end),
        )
        .fold<double>(0, (s, t) => s + t.amount);
  }

  static double _averagePositive(List<double> values) {
    final positives = values.where((v) => v > 0).toList();
    if (positives.isEmpty) return 0.0;
    return positives.fold<double>(0, (s, v) => s + v) / positives.length;
  }

  static double _expenseTrendScore(List<Transaction> txs, DateTime now) {
    final expenses = _monthlyTotals(txs, now, (t) => t.type == 'expense');
    final previous = expenses.take(3).fold<double>(0, (s, v) => s + v) / 3;
    final current = expenses.skip(3).fold<double>(0, (s, v) => s + v) / 3;
    if (previous <= 0 && current <= 0) return 0.5;
    if (previous <= 0) return 0.25;
    final change = (current - previous) / previous;
    return _clampDouble(1 - ((change + 0.10) / 0.50), 0, 1);
  }

  static double _thresholdScore(
    double value,
    List<(double threshold, double score)> thresholds,
  ) {
    for (final item in thresholds) {
      if (value >= item.$1) return item.$2;
    }
    return 0.0;
  }

  static bool _isDebtTransaction(Transaction t) {
    final text =
        '${t.categoryId} ${t.categoryName} ${t.memo} ${t.instrumentType} ${t.accountName}'
            .toLowerCase();
    return t.type == 'expense' &&
        (text.contains('emi') ||
            text.contains('loan') ||
            text.contains('credit card') ||
            text.contains('debt'));
  }

  static bool _isInvestmentTransaction(Transaction t) {
    final text =
        '${t.categoryId} ${t.categoryName} ${t.memo} ${t.payee} ${t.accountName}'
            .toLowerCase();
    return (t.type == 'expense' || t.type == 'transfer_out') &&
        (text.contains('investment') ||
            text.contains('mutual') ||
            text.contains('sip') ||
            text.contains('stock') ||
            text.contains('ppf') ||
            text.contains('epf') ||
            text.contains('nps') ||
            text.contains('gold'));
  }

  static double _accountCurrentBalance(Account account, List<Transaction> txs) {
    var balance = account.balance;
    final id = account.id.toString();
    final name = account.name.trim().toLowerCase();
    for (final tx in txs) {
      final matchesId = tx.accountId == id;
      final matchesName = tx.accountName.trim().toLowerCase() == name;
      if (!matchesId && !matchesName) continue;
      final adds = tx.type == 'income' || tx.type == 'transfer_in';
      if (account.type == 'credit_card') {
        balance += adds ? -tx.amount : tx.amount;
      } else {
        balance += adds ? tx.amount : -tx.amount;
      }
    }
    return balance;
  }

  static const Set<String> _wantCategoryIds = {
    'shopping',
    'entertainment',
    'cafe',
    'travel',
  };

  static String _pct(double value) => '${(value * 100).round()}%';

  static double _clampDouble(num value, num min, num max) =>
      value.clamp(min, max).toDouble();

  static double _sqrt(double x) {
    if (x <= 0) return 0.0;
    var guess = x;
    for (var i = 0; i < 12; i++) {
      guess = 0.5 * (guess + x / guess);
    }
    return guess;
  }
}
