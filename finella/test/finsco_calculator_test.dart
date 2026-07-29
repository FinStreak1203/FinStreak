import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/database/app_database.dart';
import 'package:finella/core/services/streak_service.dart';
import 'package:finella/features/finsco/models/finsco_score.dart';
import 'package:finella/features/finsco/services/finsco_calculator.dart';

void main() {
  final now = DateTime(2026, 7, 29);

  test('new user keeps the 40 point foundation score', () {
    final result = FinScoreCalculator.calculate(
      transactions: const [],
      accounts: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      budgetReviews: const [],
      goalContributions: const [],
      learningProgress: const [],
      streak: const StreakData.empty(),
      now: now,
    );

    expect(result.score, 40);
    expect(result.foundationScore, 40);
    expect(result.earnedPerformanceScore, 0);
    expect(result.components.length, FinScoreCategory.values.length);
  });

  test('optional categories keep base only until they become applicable', () {
    final result = FinScoreCalculator.calculate(
      transactions: const [],
      accounts: const [],
      budgets: const [],
      goals: const [],
      loans: const [],
      budgetReviews: const [],
      goalContributions: const [],
      learningProgress: const [],
      streak: const StreakData.empty(),
      now: now,
    );

    final budget = result.components.singleWhere(
      (c) => c.category == FinScoreCategory.budgetDiscipline,
    );
    final debt = result.components.singleWhere(
      (c) => c.category == FinScoreCategory.debtManagement,
    );

    expect(budget.isApplicable, isFalse);
    expect(budget.totalScore, budget.foundationScore);
    expect(debt.isApplicable, isFalse);
    expect(debt.totalScore, debt.foundationScore);
  });

  test(
    'strong financial behaviour earns performance but never exceeds 100',
    () {
      final txs = <Transaction>[
        for (var i = 0; i < 6; i++) ...[
          _tx(
            id: i * 10 + 1,
            type: 'income',
            amount: 100000,
            categoryId: 'salary',
            categoryName: 'Salary',
            date: DateTime(2026, 2 + i, 1),
          ),
          _tx(
            id: i * 10 + 2,
            type: 'expense',
            amount: 25000,
            categoryId: 'groceries',
            categoryName: 'Groceries',
            date: DateTime(2026, 2 + i, 5),
          ),
          _tx(
            id: i * 10 + 3,
            type: 'expense',
            amount: 10000,
            categoryId: 'bills',
            categoryName: 'Bills',
            date: DateTime(2026, 2 + i, 8),
          ),
          _tx(
            id: i * 10 + 4,
            type: 'transfer_out',
            amount: 15000,
            categoryId: 'investment',
            categoryName: 'Investment',
            accountName: 'SIP',
            date: DateTime(2026, 2 + i, 10),
          ),
        ],
      ];

      final result = FinScoreCalculator.calculate(
        transactions: txs,
        accounts: [
          _account(id: 1, name: 'Savings', balance: 250000),
          _account(id: 2, name: 'Emergency Fund', balance: 250000),
          _account(id: 3, name: 'SIP Investment', balance: 400000),
        ],
        budgets: [
          _budget(id: 1, categoryId: 'groceries', categoryName: 'Groceries'),
          _budget(id: 2, categoryId: 'bills', categoryName: 'Bills'),
        ],
        goals: [
          _goal(id: 1, name: 'Emergency Fund', saved: 150000, target: 250000),
        ],
        loans: const [],
        budgetReviews: const [],
        goalContributions: const [],
        learningProgress: const [],
        streak: StreakData(
          currentStreak: 30,
          totalDays: 120,
          openedDates: [
            for (var i = 0; i < 30; i++)
              DateTime(2026, 7, 29).subtract(Duration(days: i)),
          ],
        ),
        now: now,
      );

      expect(result.score, greaterThan(75));
      expect(result.score, lessThanOrEqualTo(100));
      expect(result.earnedPerformanceScore, lessThanOrEqualTo(60));
    },
  );
}

Transaction _tx({
  required int id,
  required String type,
  required double amount,
  required String categoryId,
  required String categoryName,
  required DateTime date,
  String accountName = 'Savings',
}) {
  return Transaction(
    id: id,
    type: type,
    amount: amount,
    categoryId: categoryId,
    categoryName: categoryName,
    accountId: '1',
    accountName: accountName,
    payee: categoryName,
    memo: '',
    tag: null,
    transferRef: null,
    sourceEmailId: null,
    upiRef: null,
    instrumentType: null,
    cardNumber: null,
    source: null,
    date: date,
    createdAt: date,
    isRecurring: false,
    currency: 'INR',
  );
}

Account _account({
  required int id,
  required String name,
  required double balance,
  String type = 'bank',
}) {
  return Account(
    id: id,
    name: name,
    type: type,
    balance: balance,
    currency: 'INR',
    bankName: null,
    accountNumber: null,
    imagePath: null,
    createdAt: DateTime(2026, 1, 1),
  );
}

Budget _budget({
  required int id,
  required String categoryId,
  required String categoryName,
}) {
  return Budget(
    id: id,
    categoryId: categoryId,
    categoryName: categoryName,
    limitAmount: 50000,
    year: 2026,
    month: 7,
    createdAt: DateTime(2026, 7, 1),
  );
}

Goal _goal({
  required int id,
  required String name,
  required double saved,
  required double target,
}) {
  return Goal(
    id: id,
    name: name,
    targetAmount: target,
    savedAmount: saved,
    targetDate: null,
    remindersEnabled: false,
    createdAt: DateTime(2026, 1, 1),
  );
}
