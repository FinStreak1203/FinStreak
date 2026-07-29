import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/finella_colors.dart';
import '../../../loans/viewmodel/loans_view_model.dart';
import '../../widgets/loan_card.dart';
import '../../widgets/add_loan_sheet.dart';

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansProvider);
    final activeLoans = state.loans.where((l) => l.isActive).toList();
    final closedLoans = state.loans.where((l) => !l.isActive).toList();

    return Scaffold(
      backgroundColor: FinellaColors.background,
      appBar: AppBar(
        backgroundColor: FinellaColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: FinellaColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Loans',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: FinellaColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: FinellaColors.primary, size: 28),
            onPressed: () => _showAddLoanSheet(context),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: FinellaColors.primary))
          : activeLoans.isEmpty && closedLoans.isEmpty
              ? _EmptyState(onAdd: () => _showAddLoanSheet(context))
              : RefreshIndicator(
                  onRefresh: () async => ref.invalidate(loansProvider),
                  color: FinellaColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      if (activeLoans.isNotEmpty) ...[
                        _SectionHeader(title: 'Active Loans (${activeLoans.length})'),
                        const SizedBox(height: 8),
                        ...activeLoans.map((loan) => LoanCard(
                          loan: loan,
                          onTap: () => context.push('${RouteNames.loanDetail}/$loan.id'),
                          onReconcile: () => _showReconcileDialog(context, ref, loan),
                        )),
                        const SizedBox(height: 20),
                      ],
                      if (closedLoans.isNotEmpty) ...[
                        _SectionHeader(title: 'Closed Loans (${closedLoans.length})'),
                        const SizedBox(height: 8),
                        ...closedLoans.map((loan) => LoanCard(
                          loan: loan,
                          onTap: () => context.push('${RouteNames.loanDetail}/$loan.id'),
                          onReconcile: null,
                          isClosed: true,
                        )),
                      ],
                    ],
                  ),
                ),
    );
  }

  void _showAddLoanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddLoanSheet(),
    );
  }

  void _showReconcileDialog(BuildContext context, WidgetRef ref, Loan loan) {
    final controller = TextEditingController(text: loan.outstandingAmount.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Monthly Reconciliation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Loan: ${loan.name}'),
            Text('Current Outstanding: ${_formatAmount(loan.outstandingAmount)}'),
            const SizedBox(height: 12),
            const Text('Enter Statement Balance:'),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Balance',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Compare with your lender statement. Difference will create an adjustment.',
              style: TextStyle(fontSize: 12, color: FinellaColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null) return;
              Navigator.pop(ctx);
              // TODO: Handle mismatch adjustment
              await ref.read(loansProvider.notifier).markMonthlyReconciled(loan.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Loan reconciled for this month')),
                );
              }
            },
            child: const Text('Reconcile'),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) return '₹${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '₹${(amount / 1000).toStringAsFixed(1)}K';
    return '₹${amount.toStringAsFixed(2)}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'OpenSans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: FinellaColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.account_balance_outlined, size: 48, color: FinellaColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Loans Yet',
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: FinellaColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Track home, personal, vehicle or education loans.\nMonthly reconciliation keeps your Debt Management score accurate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 14,
                color: FinellaColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Your First Loan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FinellaColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}