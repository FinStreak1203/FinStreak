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

// ── Database ──────────────────────────────────────────────

@DriftDatabase(tables: [Transactions, Goals, Accounts, Budgets])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 9;

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
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'finella.db'));
    return NativeDatabase.createInBackground(file);
  });
}
