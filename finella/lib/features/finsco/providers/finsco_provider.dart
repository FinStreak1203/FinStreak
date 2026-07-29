import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/streak_provider.dart';
import '../models/finsco_score.dart';
import '../services/finsco_calculator.dart';

final finScoreProvider = Provider<FinScoreResult>((ref) {
  final transactions =
      ref.watch(allTransactionsProvider).valueOrNull ?? const <Transaction>[];
  final accounts =
      ref.watch(allAccountsProvider).valueOrNull ?? const <Account>[];
  final budgets = ref.watch(allBudgetsProvider).valueOrNull ?? const <Budget>[];
  final goals = ref.watch(allGoalsProvider).valueOrNull ?? const <Goal>[];
  final streak = ref.watch(streakProvider);
  final loans = ref.watch(allLoansProvider).valueOrNull ?? const <Loan>[];
  final budgetReviews = ref.watch(allBudgetReviewsProvider).valueOrNull ?? const <BudgetReview>[];
  final goalContributions = ref.watch(allGoalContributionsProvider).valueOrNull ?? const <GoalContribution>[];
  final learningProgress = ref.watch(learningProgressProvider).valueOrNull ?? const <LearningProgressesData>[];

  return FinScoreCalculator.calculate(
    transactions: transactions,
    accounts: accounts,
    budgets: budgets,
    goals: goals,
    loans: loans,
    budgetReviews: budgetReviews,
    goalContributions: goalContributions,
    learningProgress: learningProgress,
    streak: streak,
    now: DateTime.now(),
  );
});

final finScoreValueProvider = Provider<int>(
  (ref) => ref.watch(finScoreProvider).score,
);
