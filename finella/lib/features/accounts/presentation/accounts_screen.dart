import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../transactions/presentation/widgets/bank_logo.dart';
import '../models/bank_model.dart';
import '../viewmodel/accounts_view_model.dart';
import 'widgets/new_account_sheet.dart';

/// Accounts overview screen.
///
/// Shown as a standalone (root-navigator) route from Settings → Account, so it
/// intentionally has no bottom tab bar. Data is sourced reactively from the
/// database via [accountsStateProvider] (MVVM: this widget is the View).
class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  void _openAccountSheet(BuildContext context, {Account? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NewAccountSheet(account: account),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountsStateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Accounts',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _openAccountSheet(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF2E7D32),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _TotalAmountCard(
                  total: state.totalAmount,
                  assets: state.assets,
                  liabilities: state.liabilities,
                  totalExpense: state.totalExpense,
                ),
                const SizedBox(height: 24),
                if (state.accounts.isEmpty)
                  const _EmptyState()
                else
                  for (final entry in state.grouped.entries) ...[
                    _GroupLabel(_typeLabel(entry.key)),
                    const SizedBox(height: 10),
                    for (final summary in entry.value) ...[
                      _AccountTile(
                        summary: summary,
                        onTap: () => _openAccountSheet(
                          context,
                          account: summary.account,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 4),
                _ImportStatementButton(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Statement import coming soon'),
                        backgroundColor: Color(0xFF2E7D32),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
    );
  }
}

// ── Type metadata (presentation only) ─────────────────────────
String _typeLabel(String type) => switch (type) {
      'cash' => 'CASH',
      'bank' => 'BANK',
      'credit_card' => 'CREDIT CARD',
      _ => type.toUpperCase(),
    };

IconData _typeIcon(String type) => switch (type) {
      'cash' => Icons.account_balance_wallet_rounded,
      'bank' => Icons.account_balance_rounded,
      'credit_card' => Icons.credit_card_rounded,
      _ => Icons.account_balance_wallet_rounded,
    };

({Color bg, Color fg}) _typeColors(String type) => switch (type) {
      'cash' => (bg: const Color(0xFFD1FADF), fg: const Color(0xFF2E7D32)),
      'bank' => (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF2563EB)),
      'credit_card' =>
        (bg: const Color(0xFFEDE9FE), fg: const Color(0xFF7C3AED)),
      _ => (bg: const Color(0xFFF3F4F6), fg: const Color(0xFF374151)),
    };

/// Indian-grouped currency, e.g. `-₹1,23,456.00`.
String formatMoney(double value) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(2);
  final parts = fixed.split('.');
  var intPart = parts[0];
  final decimals = parts[1];

  // Indian grouping: last 3 digits, then groups of 2.
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
    grouped = '$rest${buf.toString()},$last3';
  }
  return '${negative ? '-' : ''}₹$grouped.$decimals';
}

// ── Total amount hero card ────────────────────────────────────
class _TotalAmountCard extends StatelessWidget {
  final double total;
  final double assets;
  final double liabilities;
  final double totalExpense;

  const _TotalAmountCard({
    required this.total,
    required this.assets,
    required this.liabilities,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB7C9C1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatMoney(total),
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          const Divider(color: Color(0xFF1C5443), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: 'Assets',
                  value: formatMoney(assets),
                  valueColor: Colors.white,
                ),
              ),
              Expanded(
                child: _Metric(
                  label: 'Liabilities',
                  value: formatMoney(liabilities),
                  valueColor: const Color(0xFFF87171),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF1C5443), height: 1),
          const SizedBox(height: 16),
          _Metric(
            label: 'Total Spent',
            value: formatMoney(totalExpense),
            valueColor: const Color(0xFFFBBF24),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _Metric({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFFB7C9C1),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

// ── Group label ───────────────────────────────────────────────
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: Color(0xFF9CA3AF),
        ),
      );
}

// ── Account tile ──────────────────────────────────────────────
class _AccountTile extends StatelessWidget {
  final AccountSummary summary;
  final VoidCallback onTap;
  const _AccountTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _typeColors(summary.type);
    // A credit card's currentBalance is the outstanding OWED (positive = debt),
    // so show it as a negative/red liability; deposit accounts show as-is.
    final isCredit = summary.type == 'credit_card';
    final displayBalance =
        isCredit ? -summary.currentBalance : summary.currentBalance;
    final isNegative = displayBalance < 0;
    // Prefer the stored image (email-imported accounts), then resolve by name.
    final logoPath = summary.account.imagePath ??
        bankImagePathForAccount(summary.name);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF1F0)),
          ),
          child: Row(
        children: [
          if (logoPath != null)
            BankLogo(imagePath: logoPath, size: 48)
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child:
                  Icon(_typeIcon(summary.type), color: colors.fg, size: 24),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Opening: ${formatMoney(summary.openingBalance)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded,
                        size: 13, color: Color(0xFFDC2626)),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        'Total spent: ${formatMoney(summary.totalExpense)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(displayBalance),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isNegative
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF111827),
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Import statement button ───────────────────────────────────
class _ImportStatementButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ImportStatementButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.file_upload_outlined, size: 20),
        label: const Text('Import Statement'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2E7D32),
          side: const BorderSide(color: Color(0xFF2E7D32), width: 1.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: const [
          Icon(Icons.account_balance_wallet_outlined,
              size: 48, color: Color(0xFFD1D5DB)),
          SizedBox(height: 12),
          Text(
            'No accounts yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tap “New” to add your first account.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
