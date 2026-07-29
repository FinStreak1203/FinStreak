import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/finella_colors.dart';
import '../../models/loan_model.dart';
import 'widgets/loan_card.dart';

class LoanListScreen extends ConsumerWidget {
  const LoanListScreen({super.key});

  void _openLoanSheet(BuildContext context, {Loan? loan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => LoanFormSheet(loan: loan),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(allLoansProvider);

    return Scaffold(
      backgroundColor: FinellaColors.background,
      appBar: AppBar(
        backgroundColor: FinellaColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FinellaColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Loans & Debt',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: FinellaColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: () => _openLoanSheet(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('New'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: FinellaColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: loansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: FinellaColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: FinellaColors.error))),
        data: (loans) {
          final activeLoans = loans.where((l) => l.isActive).toList();
          final closedLoans = loans.where((l) => !l.isActive).toList();

          if (loans.isEmpty) {
            return _emptyState(context);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Summary card
              _SummaryCard(loans: activeLoans),
              const SizedBox(height: 16),

              // Active loans
              if (activeLoans.isNotEmpty) ...[
                _sectionHeader('Active Loans', activeLoans.length),
                const SizedBox(height: 8),
                ...activeLoans.map((loan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoanCard(loan: loan),
                )),
              ],

              // Closed loans
              if (closedLoans.isNotEmpty) ...[
                const SizedBox(height: 8),
                _sectionHeader('Closed / Paid Off', closedLoans.length),
                const SizedBox(height: 8),
                ...closedLoans.map((loan) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: LoanCard(loan: loan),
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: FinellaColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_rounded, size: 48, color: FinellaColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Loans Yet',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: FinellaColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your home loan, personal loan,\ncredit card or vehicle loan to track\ndebt in your FinScore.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: FinellaColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _openLoanSheet(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Your First Loan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FinellaColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: FinellaColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: FinellaColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: FinellaColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Loan> loans;

  const _SummaryCard({required this.loans});

  @override
  Widget build(BuildContext context) {
    final totalOutstanding = loans.fold<double>(0, (s, l) => s + l.outstandingAmount);
    final totalEMI = loans.fold<double>(0, (s, l) => s + l.emiAmount);
    final activeCount = loans.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FinellaColors.primary, Color(0xFF1B5E20)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: FinellaColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'Debt Overview',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _Metric('Outstanding', _fmt(totalOutstanding), Icons.account_balance_wallet_rounded)),
              _divider(),
              Expanded(child: _Metric('Monthly EMI', _fmt(totalEMI), Icons.calendar_month_rounded)),
              _divider(),
              Expanded(child: _Metric('Active Loans', '$activeCount', Icons.list_alt_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2));

  Widget _Metric(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }
}