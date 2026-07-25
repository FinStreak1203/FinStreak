import 'package:flutter/material.dart';
import '../../../../shared/widgets/merchant_transaction_row.dart';
import '../../../accounts/models/bank_model.dart';
import '../../models/activity_models.dart';

/// A single Activity transaction row, styled to match the merchant list design.
class TransactionRow extends StatelessWidget {
  final TransactionDisplay tx;
  final VoidCallback? onTap;

  const TransactionRow({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final category = tx.isTransfer
        ? 'transfer · ${tx.account} → ${tx.transferTo ?? '?'}'
        : '${tx.category} · ${tx.account}';

    return MerchantTransactionRow(
      name: tx.name,
      category: category,
      amount: tx.amount,
      currency: tx.currency,
      isIncome: tx.isIncome && !tx.isTransfer,
      date: tx.date,
      logoAsset: bankImagePathForAccount(tx.account),
      source: tx.source,
      dividerColor: const Color(0xFFC8E6C9), // light green, matches Insights
      redExpense: true, // expenses in red, income in green
      onTap: onTap,
    );
  }
}
