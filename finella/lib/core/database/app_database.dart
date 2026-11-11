import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ── Tables ────────────────────────────────────────────────

class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'expense', 'income', 'transfer_out', 'transfer_in'
  TextColumn get type => text()();
  RealColumn get amount => real()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text()();
  TextColumn get accountId => text()();
  TextColumn get accountName => text()();
  TextColumn get payee => text().withDefault(const Constant(''))();
  TextColumn get memo => text().withDefault(const Constant(''))();
  TextColumn get tag => text().nullable()(); // tag id, e.g. 'family' (optional)
  // Links the two rows of a transfer (transfer_out + transfer_in); null otherwise
  TextColumn get transferRef => text().nullable()();
  // Gmail import provenance + dedup (null for manual transactions).
  TextColumn get sourceEmailId => text().nullable()();
  TextColumn get upiRef => text().nullable()();
  // upi/credit_card/debit_card/imps/neft/atm/loan/cheque (null for manual).
  TextColumn get instrumentType => text().nullable()();
  TextColumn get cardNumber => text().nullable()(); // e.g. "XX1157"
  // Provenance: 'sms' for SMS imports; null for email imports / manual (email
  // is inferred from a non-null sourceEmailId). Drives the Activity badge.
  TextColumn get source => text().nullable()();
  DateTimeColumn get date => dateTime()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  // ISO currency code — 'INR' for domestic; 'USD'/'EUR'/… for foreign spends.
  TextColumn get currency =>
      text().withDefault(const Constant('INR'))();
}

class Goals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get targetAmount => real()();
  RealColumn get savedAmount => real().withDefault(const Constant(0))();
  DateTimeColumn get targetDate => dateTime().nullable()();
  BoolColumn get remindersEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'bank', 'cash', 'credit_card'
  RealColumn get balance => real()();
  TextColumn get currency =>
      text().withDefault(const Constant('INR'))();
  // Set for accounts auto-detected from email imports (null for manual ones).
  TextColumn get bankName => text().nullable()();
  TextColumn get accountNumber => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Budgets extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text()();
  RealColumn get limitAmount => real()();
  IntColumn get year => integer()();
  IntColumn get month => integer()(); // 1-12
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class LearningContents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get type => text()(); // article, video, quiz, course
  TextColumn get category => text()(); // budgeting, investing, debt, etc.
  TextColumn get contentUrl => text().nullable()();
  IntColumn get xpReward => integer().withDefault(const Constant(10))();
  IntColumn get durationMinutes => integer().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class LearningProgresses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get contentId => integer()();
  TextColumn get contentTitle => text()();
  TextColumn get contentType => text()();
  TextColumn get contentCategory => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  RealColumn get score => real().nullable()(); // for quizzes
  DateTimeColumn get completedAt => dateTime().nullable()();
  DateTimeColumn get startedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class BudgetReviews extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get budgetId => integer()();
  TextColumn get categoryId => text()();
  TextColumn get categoryName => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  RealColumn get plannedAmount => real()();
  RealColumn get actualSpent => real()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get reviewedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Loans extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // home, personal, car, education, credit_card
  RealColumn get principalAmount => real()();
  RealColumn get outstandingAmount => real()();
  RealColumn get emiAmount => real()();
  RealColumn get interestRate => real()();
  IntColumn get tenureMonths => integer()();
  IntColumn get remainingMonths => integer()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextDueDate => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get monthlyReconciledAt => dateTime().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class EmiPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get loanId => integer()();
  RealColumn get amountPaid => real()();
  DateTimeColumn get dueDate => dateTime()();
  DateTimeColumn get paidDate => dateTime().nullable()();
  BoolColumn get isPaid => boolean().withDefault(const Constant(false))();
  BoolColumn get isOnTime => boolean().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class GoalContributions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get goalId => integer()();
  RealColumn get amount => real()();
  DateTimeColumn get contributedAt =>
      dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isRecurring => boolean().withDefault(const Constant(false))();
  TextColumn get frequency => text().nullable()(); // weekly, monthly, quarterly
}

// ── Database ──────────────────────────────────────────────

@DriftDatabase(tables: [
  Transactions,
  Goals,
  Accounts,
  Budgets,
  LearningContents,
  LearningProgresses,
  BudgetReviews,
  Loans,
  EmiPayments,
  GoalContributions,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 12;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(budgets);
          }
          if (from < 3) {
            await m.addColumn(transactions, transactions.tag);
          }
          if (from < 4) {
            await m.addColumn(transactions, transactions.transferRef);
          }
          if (from < 5) {
            await m.addColumn(transactions, transactions.sourceEmailId);
            await m.addColumn(transactions, transactions.upiRef);
          }
          if (from < 6) {
            await m.addColumn(accounts, accounts.bankName);
            await m.addColumn(accounts, accounts.accountNumber);
            await m.addColumn(accounts, accounts.imagePath);
          }
          if (from < 7) {
            await m.addColumn(transactions, transactions.instrumentType);
            await m.addColumn(transactions, transactions.cardNumber);
          }
          if (from < 8) {
            await m.addColumn(transactions, transactions.source);
          }
          if (from < 9) {
            await m.addColumn(transactions, transactions.currency);
          }
          // v10 and v11 shipped the same six tables on separate branches, so
          // both pre-11 blocks used to create them — crashing on upgrade from
          // <10 ("table already exists"). Create each only if it's absent so
          // every pre-11 upgrade path lands here exactly once and safely.
          if (from < 11) {
            await _ensureTableExists(m, loans);
            await _ensureTableExists(m, emiPayments);
            await _ensureTableExists(m, budgetReviews);
            await _ensureTableExists(m, goalContributions);
            await _ensureTableExists(m, learningContents);
            await _ensureTableExists(m, learningProgresses);
          }
          if (from < 12) {
            // Guarded: a loans table freshly created by the block above is
            // built from the current schema and already has this column, so a
            // blind addColumn would throw "duplicate column name".
            await _ensureColumnExists(
              m,
              loans,
              'monthly_reconciled_at',
              loans.monthlyReconciledAt,
            );
          }
        },
      );

  /// Creates [table] only if it doesn't already exist, so a migration step can
  /// run safely regardless of which historical builds the user upgraded from.
  Future<void> _ensureTableExists(Migrator m, TableInfo table) async {
    final existing = await customSelect(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?1",
      variables: [Variable<String>(table.actualTableName)],
    ).get();
    if (existing.isEmpty) {
      await m.createTable(table);
    }
  }

  /// Adds [column] to [table] only if a column named [columnName] isn't already
  /// present (e.g. because the table was just created from the current schema).
  Future<void> _ensureColumnExists(
    Migrator m,
    TableInfo table,
    String columnName,
    GeneratedColumn column,
  ) async {
    final info =
        await customSelect('PRAGMA table_info(${table.actualTableName})').get();
    final hasColumn =
        info.any((row) => row.read<String>('name') == columnName);
    if (!hasColumn) {
      await m.addColumn(table, column);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finella.db'));
    return NativeDatabase.createInBackground(file);
  });
}
