import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';

/// A single account paired with its computed current balance.
///
/// The stored [Account.balance] is treated as the *opening* balance; the
/// [currentBalance] adds the net effect of all transactions booked against the
/// account (matched by account name).
class AccountSummary {
  final Account account;
  final double currentBalance;

  /// Total of all this account's `expense` transactions (transfers and income
  /// are excluded).
  final double totalExpense;

  const AccountSummary({
    required this.account,
    required this.currentBalance,
    this.totalExpense = 0,
  });

  String get name => account.name;
  String get type => account.type;
  double get openingBalance => account.balance;
}

/// Immutable view-state for the Accounts screen.
class AccountsState {
  final List<AccountSummary> accounts;
  final double totalAmount;
  final double assets;
  final double liabilities;

  /// Sum of every expense transaction (across all accounts, including any that
  /// couldn't be linked to a specific account).
  final double totalExpense;
  final bool isLoading;

  const AccountsState({
    this.accounts = const [],
    this.totalAmount = 0,
    this.assets = 0,
    this.liabilities = 0,
    this.totalExpense = 0,
    this.isLoading = true,
  });

  /// Accounts grouped by type, preserving the canonical type order.
  Map<String, List<AccountSummary>> get grouped {
    const order = ['cash', 'bank', 'credit_card'];
    final map = <String, List<AccountSummary>>{};
    for (final type in order) {
      final items = accounts.where((a) => a.type == type).toList();
      if (items.isNotEmpty) map[type] = items;
    }
    // Any unknown types fall through at the end.
    for (final a in accounts) {
      if (!order.contains(a.type)) {
        map.putIfAbsent(a.type, () => []).add(a);
      }
    }
    return map;
  }
}

/// Net effect of a single transaction on its account's balance.
///
/// For a credit card the stored balance is the *outstanding owed*: a spend
/// (expense) increases it and a payment/credit reduces it — the reverse of a
/// deposit account, where income adds and expenses subtract.
double _txDelta(Transaction tx, String accountType) {
  final isCredit = tx.type == 'income' || tx.type == 'transfer_in';
  if (accountType == 'credit_card') {
    return isCredit ? -tx.amount : tx.amount;
  }
  return isCredit ? tx.amount : -tx.amount;
}

/// Derived, read-only state for the Accounts screen.
///
/// Recomputes whenever accounts or transactions change in the database.
final accountsStateProvider = Provider<AccountsState>((ref) {
  final accountsAsync = ref.watch(allAccountsProvider);
  final txnsAsync = ref.watch(allTransactionsProvider);

  final accounts = accountsAsync.valueOrNull;
  if (accounts == null) return const AccountsState();

  final txns = txnsAsync.valueOrNull ?? const <Transaction>[];

  // Resolve every transaction to its account by ID first (survives renames),
  // then by name as a fallback (covers older / imported rows that only stored
  // the name). Accumulate balance deltas + total expenses per account ID so no
  // expense is missed. `totalExpenseAll` is every expense, even unlinked ones.
  final byId = {for (final a in accounts) a.id.toString(): a};
  final byName = {for (final a in accounts) a.name.trim().toLowerCase(): a};

  final deltaByAcc = <int, double>{};
  final expenseByAcc = <int, double>{};
  var totalExpenseAll = 0.0;
  for (final tx in txns) {
    if (tx.type == 'expense') totalExpenseAll += tx.amount;

    final acc =
        byId[tx.accountId] ?? byName[tx.accountName.trim().toLowerCase()];
    if (acc == null) continue; // not linkable to any account

    deltaByAcc[acc.id] = (deltaByAcc[acc.id] ?? 0) + _txDelta(tx, acc.type);
    if (tx.type == 'expense') {
      expenseByAcc[acc.id] = (expenseByAcc[acc.id] ?? 0) + tx.amount;
    }
  }

  final summaries = <AccountSummary>[];
  var assets = 0.0;
  var liabilities = 0.0;

  for (final acc in accounts) {
    final delta = deltaByAcc[acc.id] ?? 0;
    final current = acc.balance + delta;
    summaries.add(AccountSummary(
      account: acc,
      currentBalance: current,
      totalExpense: expenseByAcc[acc.id] ?? 0,
    ));

    if (acc.type == 'credit_card') {
      liabilities += current;
    } else {
      assets += current;
    }
  }

  return AccountsState(
    accounts: summaries,
    assets: assets,
    liabilities: liabilities,
    totalAmount: assets - liabilities,
    totalExpense: totalExpenseAll,
    isLoading: false,
  );
});

/// Commands for the Accounts screen — the write side of the view-model.
class AccountsViewModel {
  final Ref _ref;
  AccountsViewModel(this._ref);

  /// Adds an account, or — if one with the same name and type already exists —
  /// tops up the existing account's balance instead of creating a duplicate.
  ///
  /// Returns `true` when an existing account was merged into, `false` when a
  /// brand-new account was created.
  Future<bool> addAccount({
    required String name,
    required String type,
    required double openingBalance,
  }) async {
    final dao = _ref.read(accountDaoProvider);
    final existing = await dao.getAllAccounts();

    final key = name.trim().toLowerCase();
    Account? match;
    for (final acc in existing) {
      if (acc.name.trim().toLowerCase() == key && acc.type == type) {
        match = acc;
        break;
      }
    }

    if (match != null) {
      await dao.updateAccount(
        match.copyWith(balance: match.balance + openingBalance),
      );
      return true;
    }

    await dao.insertAccount(
      AccountsCompanion(
        name: Value(name.trim()),
        type: Value(type),
        balance: Value(openingBalance),
      ),
    );
    return false;
  }

  /// Renames / re-types / sets the opening balance of an existing account.
  Future<void> updateAccount({
    required Account account,
    required String name,
    required String type,
    required double openingBalance,
  }) {
    return _ref.read(accountDaoProvider).updateAccount(
          account.copyWith(
            name: name.trim(),
            type: type,
            balance: openingBalance,
          ),
        );
  }

  Future<void> deleteAccount(int id) =>
      _ref.read(accountDaoProvider).deleteAccount(id);
}

final accountsViewModelProvider =
    Provider<AccountsViewModel>((ref) => AccountsViewModel(ref));
