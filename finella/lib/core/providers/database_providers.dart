import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/transaction_dao.dart';
import '../database/goal_dao.dart';
import '../database/account_dao.dart';
import '../database/budget_dao.dart';
import '../database/category_dao.dart';
import '../database/recurring_dao.dart';
import '../database/learning_dao.dart';
import '../database/loan_dao.dart';
import '../database/budget_review_dao.dart';
import '../database/goal_contribution_dao.dart';
import '../../features/auth/viewmodel/auth_view_model.dart';
import 'subscription_provider.dart' show sharedPreferencesProvider;

/// Single Firestore handle for the app.
final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

/// The signed-in user's uid (null when signed out). All per-user collections
/// scope off this — when the user changes, the DAOs and streams rebuild.
final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

// ── DAOs (Firestore-backed, scoped to the current user) ───────
final transactionDaoProvider = Provider<TransactionDao>(
  (ref) => TransactionDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final goalDaoProvider = Provider<GoalDao>(
  (ref) =>
      GoalDao(ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final accountDaoProvider = Provider<AccountDao>(
  (ref) =>
      AccountDao(ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final budgetDaoProvider = Provider<BudgetDao>(
  (ref) =>
      BudgetDao(ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final recurringDaoProvider = Provider<RecurringDao>(
  (ref) => RecurringDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final categoryDaoProvider = Provider<CategoryDao>(
  (ref) => CategoryDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final learningContentDaoProvider = Provider<LearningContentDao>(
  (ref) => LearningContentDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final learningProgressDaoProvider = Provider<LearningProgressDao>(
  (ref) => LearningProgressDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final loanDaoProvider = Provider<LoanDao>(
  (ref) => LoanDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final budgetReviewDaoProvider = Provider<BudgetReviewDao>(
  (ref) => BudgetReviewDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

final goalContributionDaoProvider = Provider<GoalContributionDao>(
  (ref) => GoalContributionDao(
      ref.watch(firestoreProvider), ref.watch(currentUidProvider)),
);

// ── Reactive collections ──────────────────────────────────────
final allTransactionsProvider = StreamProvider<List<Transaction>>(
  (ref) => ref.watch(transactionDaoProvider).watchAllTransactions(),
);

final allGoalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalDaoProvider).watchAllGoals(),
);

final allAccountsProvider = StreamProvider<List<Account>>(
  (ref) => ref.watch(accountDaoProvider).watchAllAccounts(),
);

final recurringMandatesProvider = StreamProvider<List<RecurringMandate>>(
  (ref) => ref.watch(recurringDaoProvider).watchAll(),
);

/// User-defined categories (merged with the built-in ones in the UI layer).
final customCategoriesProvider = StreamProvider<List<CustomCategory>>(
  (ref) => ref.watch(categoryDaoProvider).watchAll(),
);

final allBudgetsProvider = StreamProvider<List<Budget>>(
  (ref) => ref.watch(budgetDaoProvider).watchAllBudgets(),
);

/// Seeds default accounts the first time a signed-in user has none.
/// Watched once by the main shell so it runs after login.
final userSeedProvider = FutureProvider<void>((ref) async {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return;
  final prefs = ref.read(sharedPreferencesProvider);
  await ref.read(accountDaoProvider).ensureSeeded(prefs);
});

/// Learning content stream
final learningContentProvider = StreamProvider<List<LearningContent>>(
  (ref) => ref.watch(learningContentDaoProvider).watchAll(),
);

/// Learning progress stream
final learningProgressProvider = StreamProvider<List<LearningProgressesData>>(
  (ref) => ref.watch(learningProgressDaoProvider).watchAll(),
);

/// Loans stream
final allLoansProvider = StreamProvider<List<Loan>>(
  (ref) => ref.watch(loanDaoProvider).watchAll(),
);

/// Budget reviews stream
final allBudgetReviewsProvider = StreamProvider<List<BudgetReview>>(
  (ref) => ref.watch(budgetReviewDaoProvider).watchAll(),
);

/// Goal contributions stream
final allGoalContributionsProvider = StreamProvider<List<GoalContribution>>(
  (ref) => ref.watch(goalContributionDaoProvider).watchAll(),
);
