import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/finella_colors.dart';
import '../../../../shared/widgets/merchant_transaction_row.dart' show formatIndianAmount;

class LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  final VoidCallback? onReconcile;
  final bool isClosed;

  const LoanCard({
    super.key,
    required this.loan,
    required this.onTap,
    this.onReconcile,
    this.isClosed = false,
  });

  @override
  Widget build(BuildContext context) {
    final progress = loan.principalAmount > 0
        ? 1 - (loan.outstandingAmount / loan.principalAmount)
        : 0.0;
    final monthsLeft = loan.remainingMonths;
    final isReconciledThisMonth = loan.monthlyReconciledAt != null &&
        loan.monthlyReconciledAt!.month == DateTime.now().month &&
        loan.monthlyReconciledAt!.year == DateTime.now().year;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isClosed ? FinellaColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClosed ? FinellaColors.border : FinellaColors.divider,
          ),
          boxShadow: [
            BoxShadow(
              color: FinellaColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _typeColor(loan.type).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_typeIcon(loan.type), color: _typeColor(loan.type), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                loan.name,
                                style: TextStyle(
                                  fontFamily: 'OpenSans',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isClosed ? FinellaColors.textSecondary : FinellaColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isClosed)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: FinellaColors.textSecondary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'CLOSED',
                                  style: TextStyle(
                                    fontFamily: 'OpenSans',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: FinellaColors.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _typeLabel(loan.type),
                          style: TextStyle(
                            fontFamily: 'OpenSans',
                            fontSize: 12,
                            color: isClosed ? FinellaColors.textSecondary : FinellaColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatIndianAmount(loan.outstandingAmount),
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isClosed ? FinellaColors.textSecondary : FinellaColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'EMI: ${formatIndianAmount(loan.emiAmount)}',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 11,
                          color: FinellaColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: FinellaColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(_typeColor(loan.type)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% paid off',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FinellaColors.textSecondary,
                        ),
                      ),
                      Text(
                        '$monthsLeft months left',
                        style: TextStyle(
                          fontFamily: 'OpenSans',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: FinellaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Divider + Actions
            Divider(color: FinellaColors.divider, height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  _ActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: 'Statement',
                    onTap: onTap,
                  ),
                  if (!isClosed && onReconcile != null) ...[
                    const SizedBox(width: 8),
                    _ActionButton(
                      icon: isReconciledThisMonth ? Icons.check_circle_rounded : Icons.sync_rounded,
                      label: isReconciledThisMonth ? 'Reconciled' : 'Reconcile',
                      onTap: onReconcile,
                      isPrimary: !isReconciledThisMonth,
                    ),
                  ],
                  const Spacer(),
                  _ActionButton(
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                    onTap: onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'home': return const Color(0xFF3B82F6);
      case 'personal': return const Color(0xFF8B5CF6);
      case 'vehicle': return const Color(0xFFF59E0B);
      case 'education': return const Color(0xFF10B981);
      case 'credit_card': return const Color(0xFFEF4444);
      default: return FinellaColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'home': return Icons.home_rounded;
      case 'personal': return Icons.person_rounded;
      case 'vehicle': return Icons.directions_car_rounded;
      case 'education': return Icons.school_rounded;
      case 'credit_card': return Icons.credit_card_rounded;
      default: return Icons.account_balance_rounded;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'home': return 'Home Loan';
      case 'personal': return 'Personal Loan';
      case 'vehicle': return 'Vehicle Loan';
      case 'education': return 'Education Loan';
      case 'credit_card': return 'Credit Card';
      default: return type;
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPrimary ? FinellaColors.primary : FinellaColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isPrimary ? FinellaColors.primary : FinellaColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isPrimary ? Colors.white : FinellaColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'OpenSans',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : FinellaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}