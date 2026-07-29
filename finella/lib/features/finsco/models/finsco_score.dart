class FinScoreResult {
  final int score;
  final double foundationScore;
  final double earnedPerformanceScore;
  final double rawPerformanceScore;
  final double maxRawPerformanceScore;
  final List<FinScoreComponent> components;

  const FinScoreResult({
    required this.score,
    required this.foundationScore,
    required this.earnedPerformanceScore,
    required this.rawPerformanceScore,
    required this.maxRawPerformanceScore,
    required this.components,
  });

  String get label {
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    return 'Needs work';
  }

  List<FinScoreComponent> get activeComponents =>
      components.where((c) => c.isApplicable).toList();

  List<FinScoreComponent> get strongestComponents {
    final list = [...activeComponents];
    list.sort((a, b) => b.performanceRatio.compareTo(a.performanceRatio));
    return list.take(3).toList();
  }

  List<FinScoreComponent> get improvementComponents {
    final list = [...activeComponents];
    list.sort((a, b) => a.performanceRatio.compareTo(b.performanceRatio));
    return list.take(3).toList();
  }
}

class FinScoreComponent {
  final FinScoreCategory category;
  final double foundationScore;
  final double maxPerformanceScore;
  final double earnedPerformanceScore;
  final bool isApplicable;
  final String summary;
  final String recommendation;

  const FinScoreComponent({
    required this.category,
    required this.foundationScore,
    required this.maxPerformanceScore,
    required this.earnedPerformanceScore,
    required this.isApplicable,
    required this.summary,
    required this.recommendation,
  });

  double get totalScore => foundationScore + earnedPerformanceScore;
  double get maxScore => foundationScore + maxPerformanceScore;
  double get performanceRatio => maxPerformanceScore <= 0
      ? 0.0
      : (earnedPerformanceScore / maxPerformanceScore)
            .clamp(0.0, 1.0)
            .toDouble();
}

enum FinScoreCategory {
  incomeStability(
    title: 'Income Stability',
    foundationScore: 4,
    performanceScore: 6,
  ),
  savingsDiscipline(
    title: 'Savings Discipline',
    foundationScore: 6,
    performanceScore: 9,
  ),
  expenseDiscipline(
    title: 'Expense Discipline',
    foundationScore: 6,
    performanceScore: 9,
  ),
  budgetDiscipline(
    title: 'Budget Discipline',
    foundationScore: 4,
    performanceScore: 6,
  ),
  debtManagement(
    title: 'Debt Management',
    foundationScore: 6,
    performanceScore: 9,
  ),
  emergencyFund(
    title: 'Emergency Fund',
    foundationScore: 4,
    performanceScore: 6,
  ),
  investmentHabit(
    title: 'Investment Habit',
    foundationScore: 4,
    performanceScore: 6,
  ),
  finstreakConsistency(
    title: 'Finstreak Consistency',
    foundationScore: 2,
    performanceScore: 8,
  ),
  financialGoals(
    title: 'Financial Goals',
    foundationScore: 2,
    performanceScore: 3,
  ),
  financialLearning(
    title: 'Financial Learning',
    foundationScore: 2,
    performanceScore: 8,
  );

  final String title;
  final double foundationScore;
  final double performanceScore;

  const FinScoreCategory({
    required this.title,
    required this.foundationScore,
    required this.performanceScore,
  });
}
