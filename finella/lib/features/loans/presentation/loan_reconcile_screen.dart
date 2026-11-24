import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/theme/finella_colors.dart';
import '../../../shared/widgets/merchant_transaction_row.dart' show formatIndianAmount;
import '../viewmodel/loans_view_model.dart';

/// Monthly reconciliation: compare our tracked outstanding balance with the
/// lender's statement and record the statement figure as the truth.
class LoanReconcileScreen extends ConsumerStatefulWidget {
  final int loanId;

  const LoanReconcileScreen({super.key, required this.loanId});

  @override
  ConsumerState<LoanReconcileScreen> createState() => _LoanReconcileScreenState();
}

class _LoanReconcileScreenState extends ConsumerState<LoanReconcileScreen> {
  final _ctrl = TextEditingController();
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm(Loan loan) async {
    final statement = double.tryParse(_ctrl.text.trim());
    if (statement == null || statement < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the outstanding balance from your statement')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(loansProvider.notifier).reconcile(loan.id, statement);
      if (!mounted) return;
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan reconciled for this month'),
          backgroundColor: FinellaColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reconcile: $e'), backgroundColor: FinellaColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loansProvider);
    final matches = state.loans.where((l) => l.id == widget.loanId);
    final Loan? loan = matches.isEmpty ? null : matches.first;

    if (loan != null && !_prefilled) {
      _ctrl.text = loan.outstandingAmount.toStringAsFixed(2);
      _prefilled = true;
    }

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
          'Monthly reconciliation',
          style: TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: FinellaColors.textPrimary,
          ),
        ),
        centerTitle: true,
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
              : _buildForm(loan),
    );
  }

  Widget _buildForm(Loan loan) {
    final statement = double.tryParse(_ctrl.text.trim());
    final diff = statement == null ? null : statement - loan.outstandingAmount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FinellaColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan.name,
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: FinellaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tracked outstanding: ${formatIndianAmount(loan.outstandingAmount)}',
                style: const TextStyle(fontSize: 13, color: FinellaColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Outstanding balance on your lender statement',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FinellaColors.textPrimary),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        if (diff != null) _DiffNote(diff: diff),
        const SizedBox(height: 8),
        const Text(
          'The statement balance is saved as this loan\'s outstanding amount. '
          'Any difference is treated as an adjustment.',
          style: TextStyle(fontSize: 12, color: FinellaColors.textTertiary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _saving ? null : () => _confirm(loan),
            style: ElevatedButton.styleFrom(
              backgroundColor: FinellaColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Confirm reconciliation'),
          ),
        ),
      ],
    );
  }
}

class _DiffNote extends StatelessWidget {
  final double diff;

  const _DiffNote({required this.diff});

  @override
  Widget build(BuildContext context) {
    final matches = diff.abs() < 0.005;
    final text = matches
        ? 'Matches your tracked balance.'
        : diff > 0
            ? 'Statement is ${formatIndianAmount(diff)} higher than tracked.'
            : 'Statement is ${formatIndianAmount(-diff)} lower than tracked.';
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: matches ? FinellaColors.success : FinellaColors.warning,
      ),
    );
  }
}
