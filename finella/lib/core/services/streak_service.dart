import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../database/app_database.dart';
import '../database/account_dao.dart';
import '../database/transaction_dao.dart';

// ══════════════════════════════════════════════════════════════
// StreakData — immutable snapshot of the user's reconciliation streak
// ══════════════════════════════════════════════════════════════
class StreakData {
  final int currentStreak;
  final int longestStreak;
  final int totalDays;

  /// Calendar dates the user successfully reconciled (drives the heatmap).
  final List<DateTime> openedDates;

  /// Last successful reconciliation, or null if never reconciled.
  final DateTime? lastReconciled;

  /// Whether this month's premium streak-recovery has been used.
  final bool recoveryUsed;

  /// First-of-month marker for the current [recoveryUsed] flag — recovery
  /// resets when the calendar month rolls past this.
  final DateTime? recoveryResetDate;

  static const int goal = 250;

  const StreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.totalDays = 0,
    this.openedDates = const [],
    this.lastReconciled,
    this.recoveryUsed = false,
    this.recoveryResetDate,
  });

  const StreakData.empty() : this();

  double get progress => (totalDays / goal).clamp(0.0, 1.0);
  int get daysRemaining => (goal - totalDays).clamp(0, goal);
  int get percentage => (progress * 100).toInt();

  /// True when the last reconciliation happened today.
  bool get hasReconciledToday {
    final last = lastReconciled;
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year &&
        last.month == now.month &&
        last.day == now.day;
  }
}

/// Net effect of one transaction on the overall balance (income & incoming
/// transfers add; expenses & outgoing transfers subtract).
double _txDelta(Transaction t) => switch (t.type) {
      'income' || 'transfer_in' => t.amount,
      _ => -t.amount,
    };

/// Breakdown shown on the reconcile screen and used to derive the expected
/// closing balance. Shared by the screen (reactive) and the service.
typedef ReconcileSummary = ({
  double opening,
  double income,
  double expense,
  double expected,
});

/// Pure computation of today's expected closing balance:
///   opening (all account balances + every transaction before today)
///   + today's income − today's expense.
/// Transfers net to zero across accounts, so they're left out of the
/// income/expense display and don't affect `expected`.
ReconcileSummary computeReconcileSummary(
  List<Account> accounts,
  List<Transaction> txns,
  DateTime now,
) {
  final startToday = DateTime(now.year, now.month, now.day);
  var opening = accounts.fold<double>(0, (s, a) => s + a.balance);
  var income = 0.0;
  var expense = 0.0;

  for (final t in txns) {
    final d = DateTime(t.date.year, t.date.month, t.date.day);
    if (d.isBefore(startToday)) {
      opening += _txDelta(t);
    } else if (d == startToday) {
      if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'expense') {
        expense += t.amount;
      }
      // transfers net to zero across accounts → ignored
    }
    // future-dated transactions are ignored
  }

  return (
    opening: opening,
    income: income,
    expense: expense,
    expected: opening + income - expense,
  );
}

// ══════════════════════════════════════════════════════════════
// StreakService — Firestore-backed, driven by daily reconciliation
// Doc: users/{uid}/streak/data
// ══════════════════════════════════════════════════════════════
class StreakService {
  /// ₹ tolerance — a difference within this counts as a successful reconcile.
  static const double tolerance = 5.0;

  final FirebaseFirestore _db;
  final String? _uid;
  final TransactionDao _txDao;
  final AccountDao _accountDao;

  StreakService(this._db, this._uid, this._txDao, this._accountDao);

  DocumentReference<Map<String, dynamic>>? get _doc => _uid == null
      ? null
      : _db.collection('users').doc(_uid).collection('streak').doc('data');

  // ── Reads ─────────────────────────────────────────────────
  Stream<StreakData> watch() {
    final doc = _doc;
    if (doc == null) return Stream.value(const StreakData.empty());
    return doc.snapshots().map((s) => _fromMap(s.data()));
  }

  Future<StreakData> get() async {
    final doc = _doc;
    if (doc == null) return const StreakData.empty();
    final snap = await doc.get();
    return _fromMap(snap.data());
  }

  /// Today's expected closing balance (see [computeReconcileSummary]).
  Future<double> getExpectedBalance() async => (await getSummary()).expected;

  /// Full opening / income / expense / expected breakdown.
  Future<ReconcileSummary> getSummary() async {
    final accounts = await _accountDao.getAllAccounts();
    final txns = await _txDao.getAllTransactions();
    return computeReconcileSummary(accounts, txns, DateTime.now());
  }

  // ── Reconcile ─────────────────────────────────────────────
  /// Returns true when [actualBalance] matches [expectedBalance] within
  /// [tolerance] — incrementing the streak — or false on a mismatch.
  Future<bool> reconcile({
    required double actualBalance,
    required double expectedBalance,
  }) async {
    final difference = (expectedBalance - actualBalance).abs();
    if (difference > tolerance) return false;

    final doc = _doc;
    if (doc == null) return false;

    final now = DateTime.now();
    final todayStr = _dateStr(now);
    final data = (await doc.get()).data() ?? const {};

    final history = List<String>.from(
        (data['reconcileHistory'] as List?)?.cast<String>() ?? const []);
    var current = (data['currentStreak'] as num?)?.toInt() ?? 0;
    var longest = (data['longestStreak'] as num?)?.toInt() ?? 0;
    var total = (data['totalDays'] as num?)?.toInt() ?? 0;
    final last = (data['lastReconciled'] as Timestamp?)?.toDate();

    // Only advance the streak the first time we reconcile on a given day.
    if (!history.contains(todayStr)) {
      if (last != null) {
        final gap = _dayGap(last, now);
        current = gap == 1 ? current + 1 : 1; // gap >= 2 → streak broke
      } else {
        current = 1;
      }
      if (current > longest) longest = current;
      total += 1;
      history.add(todayStr);
    }

    await doc.set({
      'currentStreak': current,
      'longestStreak': longest,
      'totalDays': total,
      'lastReconciled': Timestamp.fromDate(now),
      'reconcileHistory': history,
      'recoveryUsed': data['recoveryUsed'] ?? false,
    }, SetOptions(merge: true));

    return true;
  }

  /// Whether the streak has lapsed: reconciled before, not today, and more
  /// than a full day has passed since the last reconcile.
  bool isStreakBroken(StreakData d) {
    final last = d.lastReconciled;
    if (last == null || d.hasReconciledToday) return false;
    return _dayGap(last, DateTime.now()) > 1;
  }

  /// Resets the current streak to 0 in Firestore if it has lapsed.
  Future<void> resetStreakIfBroken() async {
    final doc = _doc;
    if (doc == null) return;
    final d = await get();
    if (isStreakBroken(d) && d.currentStreak != 0) {
      await doc.set({'currentStreak': 0}, SetOptions(merge: true));
    }
  }

  // ── Premium streak recovery (1 per calendar month) ────────
  /// Whether a recovery is available this month — true if it hasn't been used,
  /// or the month has rolled over since it was last used.
  bool recoveryAvailable(StreakData d) {
    if (!d.recoveryUsed) return true;
    final reset = d.recoveryResetDate;
    if (reset == null) return false; // used, no marker → treat as used
    final now = DateTime.now();
    // A new calendar month has started since the flag was set.
    return now.year > reset.year ||
        (now.year == reset.year && now.month > reset.month);
  }

  /// Saves a lapsed streak for premium users by bridging the missed day, so the
  /// current streak survives. Consumes the month's single recovery. Returns
  /// false if not premium, no recovery left, or the streak isn't broken.
  Future<bool> useStreakRecovery({required bool isPremium}) async {
    if (!isPremium) return false;
    final doc = _doc;
    if (doc == null) return false;

    final d = await get();
    if (!recoveryAvailable(d) || !isStreakBroken(d)) return false;

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    final firstOfMonth = DateTime(now.year, now.month, 1);

    // Bridge the gap (streak no longer counts as broken) and mark recovery used
    // for this month. currentStreak is left intact — the streak is preserved.
    await doc.set({
      'lastReconciled': Timestamp.fromDate(yesterday),
      'recoveryUsed': true,
      'recoveryResetDate': Timestamp.fromDate(firstOfMonth),
    }, SetOptions(merge: true));
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────
  StreakData _fromMap(Map<String, dynamic>? data) {
    if (data == null) return const StreakData.empty();
    final history = (data['reconcileHistory'] as List?)?.cast<String>() ?? [];
    return StreakData(
      currentStreak: (data['currentStreak'] as num?)?.toInt() ?? 0,
      longestStreak: (data['longestStreak'] as num?)?.toInt() ?? 0,
      totalDays: (data['totalDays'] as num?)?.toInt() ?? 0,
      openedDates: history
          .map((s) => DateTime.tryParse(s))
          .whereType<DateTime>()
          .toList(),
      lastReconciled: (data['lastReconciled'] as Timestamp?)?.toDate(),
      recoveryUsed: data['recoveryUsed'] as bool? ?? false,
      recoveryResetDate: (data['recoveryResetDate'] as Timestamp?)?.toDate(),
    );
  }

  /// Calendar-day gap between two dates (ignores time of day).
  static int _dayGap(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  static String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';
}
