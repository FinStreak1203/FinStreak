import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/bank_assets.dart';
import '../database/app_database.dart';
import '../database/account_dao.dart';
import '../database/recurring_dao.dart';
import '../database/transaction_dao.dart';
import '../providers/database_providers.dart';
import 'category_classifier.dart';
import 'email_parser_service.dart' show ParsedTransaction;

/// Persists a single [ParsedTransaction] to the database, applying the same
/// dedup, account auto-creation and mandate routing the SMS import screen uses.
///
/// Extracted so the real-time SMS listener writes through the exact same path
/// as the on-demand import — one source of truth for "how a parsed txn is
/// saved". Each [save] re-reads existing rows for dedup, which is fine for the
/// one-at-a-time cadence of live SMS (not for bulk imports).
class TransactionImporter {
  final TransactionDao _txDao;
  final AccountDao _accountDao;
  final RecurringDao _recurringDao;

  const TransactionImporter(this._txDao, this._accountDao, this._recurringDao);

  /// Saves [t], skipping anything already imported (by SMS id, UPI ref, or a
  /// content signature) and auto-creating the referenced bank account. A UPI
  /// mandate setup is routed to the recurring list instead of the ledger.
  /// Returns true when a new row (or mandate) was actually written.
  Future<bool> save(ParsedTransaction t) async {
    try {
      // ── UPI mandate setup → recurring list, not the ledger ──
      if (t.category == 'UPI Mandate Setup') {
        return _recurringDao.addIfNew(
          name: (t.merchant != null && t.merchant!.isNotEmpty)
              ? t.merchant!
              : t.bankName,
          amount: t.amount,
          bankName: t.bankName,
          umn: t.upiVpa ?? '',
        );
      }

      // ── Dedup against what's already stored ──
      final existing = await _txDao.getAllTransactions();
      final ref = t.upiRef;
      final ck = _contentKey(
          t.type, t.amount, t.date, t.merchant, t.accountNumber);
      for (final e in existing) {
        if (e.sourceEmailId != null &&
            e.sourceEmailId!.isNotEmpty &&
            e.sourceEmailId == t.emailId) {
          return false;
        }
        if (ref != null &&
            ref.isNotEmpty &&
            e.upiRef != null &&
            e.upiRef == ref) {
          return false;
        }
        if ((ref == null || ref.isEmpty) &&
            _contentKey(e.type, e.amount, e.date, e.payee, e.cardNumber) ==
                ck) {
          return false;
        }
      }

      // ── Auto-create the referenced account if it's new ──
      await _maybeCreateAccount(t);

      final account =
          await _accountDao.findByBankAndNumber(t.bankName, t.accountNumber);
      final accountId = account?.id.toString() ??
          t.bankName.toLowerCase().replaceAll(' ', '_');
      final accountName = account?.name ?? t.bankName;

      // Offline categorisation (same matcher as the import screens).
      var categoryId = 'other';
      var categoryName =
          (t.category != null && t.category!.isNotEmpty) ? t.category! : 'Other';
      final cat = CategoryClassifier.classify(t.merchant);
      if (cat != null) {
        categoryId = cat.id;
        categoryName = cat.name;
      }

      await _txDao.insertTransaction(
        TransactionsCompanion.insert(
          type: t.type,
          amount: t.amount,
          categoryId: categoryId,
          categoryName: categoryName,
          accountId: accountId,
          accountName: accountName,
          date: t.date,
          payee: Value(t.merchant ?? ''),
          memo: Value(_buildMemo(t)),
          sourceEmailId: Value(t.emailId),
          upiRef: Value(t.upiRef),
          instrumentType: Value(t.instrumentType),
          cardNumber: Value(t.accountNumber),
          isRecurring: Value(t.isRecurring),
          currency: Value(t.currency),
          source: const Value('sms'),
        ),
      );
      return true;
    } catch (e) {
      debugPrint('TransactionImporter.save error: $e');
      return false;
    }
  }

  /// Creates the bank account referenced by [t] if it isn't in the DB yet.
  /// Deduped by bank + masked number, matching the import screen.
  Future<void> _maybeCreateAccount(ParsedTransaction t) async {
    final number = t.accountNumber;
    if (number == null || number.isEmpty) return;
    if (await _accountDao.findByBankAndNumber(t.bankName, number) != null) {
      return;
    }
    try {
      await _accountDao.insertAccount(
        AccountsCompanion.insert(
          name: '${t.bankName} $number',
          type: t.accountType == 'credit_card' ? 'credit_card' : 'bank',
          balance: 0,
          bankName: Value(t.bankName),
          accountNumber: Value(number),
          imagePath: Value(BankAssets.getImagePath(t.bankName)),
        ),
      );
    } catch (_) {
      // A failed account isn't fatal — the transaction still saves.
    }
  }

  /// Content signature for txns without a UPI reference (e.g. card "spent"
  /// alerts) — comparable across the parsed model and the stored row.
  String _contentKey(String type, double amount, DateTime date,
      String? merchant, String? acct) {
    final m = (merchant ?? '').toLowerCase().trim();
    final a = (acct ?? '').toLowerCase().trim();
    return '$type|${amount.toStringAsFixed(2)}|'
        '${date.year}-${date.month}-${date.day}|$m|$a';
  }

  /// Persists the UPI reference and VPA in the memo (no dedicated columns).
  String _buildMemo(ParsedTransaction t) {
    final parts = <String>[];
    if (t.upiRef != null && t.upiRef!.isNotEmpty) parts.add('Ref: ${t.upiRef}');
    if (t.upiVpa != null && t.upiVpa!.isNotEmpty) parts.add(t.upiVpa!);
    return parts.isEmpty ? 'Imported from SMS' : parts.join(' · ');
  }
}

final transactionImporterProvider = Provider<TransactionImporter>(
  (ref) => TransactionImporter(
    ref.watch(transactionDaoProvider),
    ref.watch(accountDaoProvider),
    ref.watch(recurringDaoProvider),
  ),
);
