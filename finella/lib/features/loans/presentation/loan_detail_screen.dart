import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/finella_colors.dart';
import '../../../shared/widgets/merchant_transaction_row.dart' show formatIndianAmount;
import '../viewmodel/loans_view_model.dart';
import 'widgets/add_loan_sheet.dart';

class LoanDetailScreen extends ConsumerWidget {
  final int loanId;

  const LoanDetailScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loansProvider);
    final matches = state.loans.where((l) => l.id == loanId);
    final Loan? loan = matches.isEmpty ? null : matches.first;

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
          'Loan details',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: FinellaColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          if (loan != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: FinellaColors.primary),
              onPressed: () => _edit(context, loan),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: FinellaColors.error),
              onPressed: () => _confirmDelete(context, ref, loan),
            ),
          ],
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(color: FinellaColors.primary))
          : loan == null
              ? const Center(
                  child: Text(
                    'This loan no longer exists.',
                    style: TextStyle(color: FinellaColors.textSecondary),
                  ),
                )
              : _Body(loan: loan),
    );
  }

  void _edit(BuildContext context, Loan loan) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LoanFormSheet(loan: loan),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Loan loan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete loan?'),
        content: Text('"${loan.name}" and its tracking history will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: FinellaColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(loansProvider.notifier).deleteLoan(loan.id);
    if (context.mounted) context.pop();
  }
}

class _Body extends StatelessWidget {
  final Loan loan;

  const _Body({required this.loan});

  @override
  Widget build(BuildContext context) {
    final double paidFraction = loan.principalAmount > 0
        ? (1 - loan.outstandingAmount / loan.principalAmount).clamp(0.0, 1.0).toDouble()
        : 0.0;
    // Interest still to be paid if the remaining EMIs run to the end of the loan.
    final double interestLeft =
        (loan.emiAmount * loan.remainingMonths - loan.outstandingAmount).clamp(0.0, double.infinity).toDouble();
    final last = loan.monthlyReconciledAt;
    final reconciledThisMonth = last != null &&
        last.year == DateTime.now().year &&
        last.month == DateTime.now().month;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FinellaColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan.name,
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: FinellaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                loanTypeLabel(loan.type),
                style: const TextStyle(fontSize: 12, color: FinellaColors.textTertiary),
              ),
              const SizedBox(height: 16),
              const Text('Outstanding', style: TextStyle(fontSize: 12, color: FinellaColors.textSecondary)),
              Text(
                formatIndianAmount(loan.outstandingAmount),
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: FinellaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: paidFraction,
                  minHeight: 6,
                  backgroundColor: FinellaColors.divider,
                  color: FinellaColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(paidFraction * 100).toStringAsFixed(0)}% paid off',
                style: const TextStyle(fontSize: 11, color: FinellaColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _DetailCard(rows: [
          _Row('Principal', formatIndianAmount(loan.principalAmount)),
          _Row('EMI', formatIndianAmount(loan.emiAmount)),
          _Row('Interest rate', '${loan.interestRate.toStringAsFixed(2)}% p.a.'),
          _Row('Remaining', '${loan.remainingMonths} of ${loan.tenureMonths} months'),
          _Row('Interest still to pay', formatIndianAmount(interestLeft)),
          _Row('Start date', _fmtDate(loan.startDate)),
          _Row('Next due', _fmtDate(loan.nextDueDate)),
          _Row('Last reconciled', last == null ? 'Not yet' : _fmtDate(last)),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => context.push('${RouteNames.loanReconcile}/${loan.id}'),
            icon: Icon(reconciledThisMonth ? Icons.check_circle_rounded : Icons.sync_rounded),
            label: Text(reconciledThisMonth ? 'Reconciled this month' : 'Reconcile with statement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinellaColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<_Row> rows;

  const _DetailCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FinellaColors.divider),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: FinellaColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].label,
                      style: const TextStyle(fontSize: 13, color: FinellaColors.textSecondary)),
                  Text(rows[i].value,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: FinellaColors.textPrimary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final String value;

  const _Row(this.label, this.value);
}

/// Human label for the loan type stored on each loan.
String loanTypeLabel(String type) {
  switch (type) {
    case 'home':
      return 'Home Loan';
    case 'personal':
      return 'Personal Loan';
    case 'vehicle':
      return 'Vehicle Loan';
    case 'education':
      return 'Education Loan';
    case 'credit_card':
      return 'Credit Card';
    default:
      return type;
  }
}

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}
