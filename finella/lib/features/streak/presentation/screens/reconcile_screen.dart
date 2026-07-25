import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/providers/streak_provider.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/streak_service.dart';
import '../../../transactions/presentation/category_picker_sheet.dart';
import '../../models/reconcile_result.dart';

const _kDark = Color(0xFF1A3C34);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF7FAF4);

/// Indian-grouped currency, e.g. `₹1,23,456`. Shared by the reconcile screens.
String formatRupee(double value, {bool sign = false}) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(2);
  final parts = fixed.split('.');
  var intPart = parts[0];
  String grouped;
  if (intPart.length <= 3) {
    grouped = intPart;
  } else {
    final last3 = intPart.substring(intPart.length - 3);
    var rest = intPart.substring(0, intPart.length - 3);
    final buf = StringBuffer();
    while (rest.length > 2) {
      buf.write(',${rest.substring(rest.length - 2)}');
      rest = rest.substring(0, rest.length - 2);
    }
    grouped = '$rest$buf,$last3';
  }
  final prefix = negative ? '-' : (sign ? '+' : '');
  return '$prefix₹$grouped.${parts[1]}';
}

class ReconcileScreen extends ConsumerStatefulWidget {
  const ReconcileScreen({super.key});

  @override
  ConsumerState<ReconcileScreen> createState() => _ReconcileScreenState();
}

class _ReconcileScreenState extends ConsumerState<ReconcileScreen> {
  final _amountCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Lapse the streak (if a day was missed) before showing the count.
    ref.read(streakServiceProvider).resetStreakIfBroken();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _reconcileNow(double expected) async {
    final actual = double.tryParse(_amountCtrl.text.trim());
    if (actual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter your current bank balance'),
          backgroundColor: _kRed,
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final service = ref.read(streakServiceProvider);
    final prev = ref.read(streakProvider).currentStreak;
    final ok =
        await service.reconcile(actualBalance: actual, expectedBalance: expected);
    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      final fresh = await service.get();
      // Already reconciled today → push the reminder to tomorrow 9 PM.
      await NotificationService.instance
          .scheduleDailyReconcileReminder(reconciledToday: true);
      if (!mounted) return;
      context.pushReplacement(
        RouteNames.reconcileSuccess,
        extra: ReconcileResult(
          expected: expected,
          actual: actual,
          previousStreak: prev,
          newStreak: fresh.currentStreak,
        ),
      );
    } else {
      context.push(
        RouteNames.reconcileMismatch,
        extra: ReconcileResult(
          expected: expected,
          actual: actual,
          previousStreak: prev,
          newStreak: prev,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider).valueOrNull ?? const [];
    final txns = ref.watch(allTransactionsProvider).valueOrNull ?? const [];
    final streak = ref.watch(streakProvider);
    final summary = computeReconcileSummary(accounts, txns, DateTime.now());

    final now = DateTime.now();
    final todayTxns = txns
        .where((t) =>
            t.date.year == now.year &&
            t.date.month == now.month &&
            t.date.day == now.day)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: _kBg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _header(streak.currentStreak),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _summaryCard(summary, now),
                const SizedBox(height: 16),
                _balanceInput(),
                const SizedBox(height: 16),
                _whyCard(),
                const SizedBox(height: 16),
                _recentTransactions(todayTxns),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _submitting
                        ? null
                        : () => _reconcileNow(summary.expected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kGreen,
                      disabledBackgroundColor: const Color(0xFF9CA3AF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Reconcile Now',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Reconcile Later',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _kGreen)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────
  Widget _header(int streakDays) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 0, 20, 24),
      decoration: const BoxDecoration(color: _kDark),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => context.pop(),
                ),
                const Spacer(),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Let's close your day 🎯",
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 8),
                        Text(
                          'Add your closing bank balance and reconcile '
                          'to keep your R-Streak alive.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Colors.white.withValues(alpha: 0.75)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StreakBadge(days: streakDays),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's summary ───────────────────────────────────────
  Widget _summaryCard(ReconcileSummary s, DateTime now) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Today's Summary",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827))),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 6),
                  Text('${now.day} ${months[now.month]} ${now.year}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _summaryRow('Opening Balance', formatRupee(s.opening)),
          const SizedBox(height: 10),
          _summaryRow('Total Income', formatRupee(s.income, sign: true),
              color: const Color(0xFF22C55E)),
          const SizedBox(height: 10),
          _summaryRow('Total Expenses', '- ${formatRupee(s.expense)}',
              color: _kRed),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text('Expected Closing Balance',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827))),
                  SizedBox(width: 4),
                  Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFF9CA3AF)),
                ],
              ),
              Text(formatRupee(s.expected),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _kGreen)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF374151))),
        Text(value,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? const Color(0xFF111827))),
      ],
    );
  }

  // ── Bank balance input ────────────────────────────────────
  Widget _balanceInput() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Enter Current Bank Balance',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 4),
          const Text("What's the current balance in your bank?",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF))),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7FAF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                const Text('₹',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B7280))),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827)),
                    decoration: const InputDecoration(
                      hintText: 'Enter amount',
                      hintStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFD1D5DB)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('As per your bank statement / passbook',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }

  Widget _whyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Why reconcile daily?',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E))),
                SizedBox(height: 4),
                Text(
                  'Daily reconciliation helps you stay accurate, spot missing '
                  'transactions and build a strong money habit.',
                  style: TextStyle(
                      fontSize: 13, height: 1.4, color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent transactions today ─────────────────────────────
  Widget _recentTransactions(List<Transaction> txns) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent Transactions Today',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),
          if (txns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No transactions today yet.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
            )
          else
            for (final t in txns.take(5)) _txRow(t),
        ],
      ),
    );
  }

  Widget _txRow(Transaction t) {
    final isIncome = t.type == 'income' || t.type == 'transfer_in';
    final cat = _categoryFor(t.categoryId);
    final h = t.date.hour % 12 == 0 ? 12 : t.date.hour % 12;
    final period = t.date.hour < 12 ? 'AM' : 'PM';
    final time = '$h:${t.date.minute.toString().padLeft(2, '0')} $period';
    final label = t.payee.trim().isNotEmpty ? t.payee.trim() : t.categoryName;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: cat?.bgColor ?? const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(cat?.icon ?? Icons.receipt_long_rounded,
                size: 19, color: cat?.iconColor ?? const Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                const SizedBox(height: 1),
                Text(t.categoryName,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+ ' : '- '}${formatRupee(t.amount)}',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isIncome ? const Color(0xFF22C55E) : _kRed),
              ),
              const SizedBox(height: 1),
              Text(time,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }

  CategoryItem? _categoryFor(String id) {
    for (final c in [...allCategories, ...incomeCategories]) {
      if (c.id == id) return c;
    }
    return null;
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFF1F0)),
        ),
        child: child,
      );
}

// ── R-Streak badge (top-right of the header) ──────────────────
class _StreakBadge extends StatelessWidget {
  final int days;
  const _StreakBadge({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: const Color(0xFF7CD3A8), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('R⚡',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF7CD3A8))),
          Text('$days',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.1)),
          const Text('Days',
              style: TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}
