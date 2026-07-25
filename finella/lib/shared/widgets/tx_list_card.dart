import 'package:flutter/material.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/finella_colors.dart';
import '../../features/accounts/models/bank_model.dart';
import '../../features/transactions/presentation/widgets/bank_logo.dart';

class TransactionListCard extends StatelessWidget {
  final List<TransactionData> transactions;
  final VoidCallback onSeeAll;
  final void Function(TransactionData)? onRowTap;

  const TransactionListCard({
    super.key,
    required this.transactions,
    required this.onSeeAll,
    this.onRowTap,
  });

  String _fmt(double v) => v.toStringAsFixed(0);

  String _fmtDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FinellaColors.textDark)),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text('All →', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FinellaColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (final tx in transactions)
                _TxRow(
                  tx: tx,
                  fmtDate: _fmtDate,
                  fmt: _fmt,
                  onTap: onRowTap != null ? () => onRowTap!(tx) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TxRow extends StatelessWidget {
  final TransactionData tx;
  final String Function(DateTime) fmtDate;
  final String Function(double) fmt;
  final VoidCallback? onTap;

  const _TxRow({required this.tx, required this.fmtDate, required this.fmt, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6), width: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _Avatar(
                icon: tx.categoryIcon,
                color: tx.categoryColor,
                bankLogo: bankImagePathForAccount(tx.accountName),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (tx.isTransfer)
                      Text(
                        '${tx.accountName} → ${tx.transferTo ?? '?'} · ${fmtDate(tx.date)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: FinellaColors.textGray,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '${tx.category} · ${fmtDate(tx.date)}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: FinellaColors.textGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFE5E7EB), width: 0.5),
                            ),
                            child: Text(
                              tx.accountName,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
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
                tx.isTransfer
                    ? '₹${fmt(tx.amount)}'
                    : '${tx.isExpense ? '-' : '+'}₹${fmt(tx.amount)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: tx.isTransfer
                      ? const Color(0xFF1565C0)
                      : (tx.isExpense
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF22C55E)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Category-icon avatar with an optional bank-logo corner badge.
class _Avatar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? bankLogo;

  const _Avatar({required this.icon, required this.color, this.bankLogo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          if (bankLogo != null)
            Positioned(
              right: -2,
              bottom: -2,
              child: BankBadge(imagePath: bankLogo!),
            ),
        ],
      ),
    );
  }
}
