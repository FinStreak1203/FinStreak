import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/category_options.dart';
import '../../core/constants/transaction_tags.dart';
import '../../core/database/app_database.dart';
import '../../core/database/category_dao.dart';
import '../../core/services/gmail_service.dart';
import 'tag_badge.dart';
import '../../core/providers/database_providers.dart';
import '../../core/router/app_router.dart' show appRootNavigatorKey;
import '../../features/transactions/presentation/category_picker_sheet.dart';
import '../../features/transactions/presentation/new_transaction_screen.dart';

// ── Public entry point ────────────────────────────────────────
void showTransactionDetail({
  required BuildContext context,
  required WidgetRef ref,
  required Transaction transaction,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => TransactionDetailSheet(
      transaction: transaction,
      onEdit: () {
        Navigator.pop(ctx);
        appRootNavigatorKey.currentState?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                NewTransactionScreen(editTransaction: transaction),
          ),
        );
      },
      onDelete: () async {
        Navigator.pop(ctx);
        await _confirmDelete(context, ref, transaction);
      },
    ),
  );
}

// ── Confirm-delete dialog ─────────────────────────────────────
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Transaction tx,
) async {
  final txName =
      tx.payee.isNotEmpty ? tx.payee : tx.categoryName;
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Transaction?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'This will permanently delete "$txName" '
        '(₹${tx.amount.toStringAsFixed(2)}).',
        style: const TextStyle(
            fontSize: 14, color: Color(0xFF6B7280)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    final dao = ref.read(transactionDaoProvider);
    // Transfers are two linked rows — delete both via the shared ref.
    if (tx.transferRef != null) {
      await dao.deleteByTransferRef(tx.transferRef!);
    } else {
      await dao.deleteTransaction(tx.id);
    }
    // If this row came from a Gmail import, clear its "processed" flag so the
    // email can be re-imported later (SMS rows use source 'sms' and a different
    // dedup key, so leave those alone). Without this a deleted email
    // transaction could never come back.
    final emailId = tx.sourceEmailId;
    if (emailId != null && emailId.isNotEmpty && tx.source != 'sms') {
      await ref.read(gmailServiceProvider).clearProcessed(emailId);
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction deleted'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
    }
    // StreamProviders auto-refresh the UI
  }
}

// ══════════════════════════════════════════════════════════════
// TransactionDetailSheet
// ══════════════════════════════════════════════════════════════
class TransactionDetailSheet extends ConsumerStatefulWidget {
  final Transaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TransactionDetailSheet({
    super.key,
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  // Local, editable category (updated inline via the category picker).
  late String _catId = widget.transaction.categoryId;
  late String _catName = widget.transaction.categoryName;

  // Getters so the existing build body can keep using `transaction` / `onEdit`.
  Transaction get transaction => widget.transaction;
  VoidCallback get onEdit => widget.onEdit;
  VoidCallback get onDelete => widget.onDelete;

  /// Opens the category picker and persists the chosen category on this
  /// transaction — the fix for a mis-detected (or "Other") category.
  void _pickCategory() {
    final type = transaction.type == 'income' ? 'income' : 'expense';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7FAF4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => CategoryPickerSheet(
          scrollCtrl: controller,
          type: type,
          onSelect: _updateCategory,
        ),
      ),
    );
  }

  Future<void> _updateCategory(String id, String name) async {
    setState(() {
      _catId = id;
      _catName = name;
    });
    await ref.read(transactionDaoProvider).updateTransaction(
          widget.transaction.copyWith(categoryId: id, categoryName: name),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type.startsWith('transfer');
    const transferBlue = Color(0xFF1565C0);

    final typeLabel = isTransfer
        ? 'TRANSFER'
        : (isExpense ? 'EXPENSE' : 'INCOME');
    final accentColor = isTransfer
        ? transferBlue
        : (isExpense ? const Color(0xFFEF4444) : const Color(0xFF22C55E));
    final amountText = isTransfer
        ? '₹${_formatAmount(transaction.amount)}'
        : '${isExpense ? "-" : "+"}₹${_formatAmount(transaction.amount)}';

    // Resolve the current category's chip visuals — custom categories first,
    // then the built-in switches.
    final customCats =
        ref.watch(customCategoriesProvider).valueOrNull ?? const <CustomCategory>[];
    CustomCategory? cc;
    for (final c in customCats) {
      if (c.id == _catId) {
        cc = c;
        break;
      }
    }
    final catIcon =
        cc != null ? categoryIconFor(cc.iconKey) : _categoryIcon(_catId);
    final catBg =
        cc != null ? categoryColorFor(cc.colorKey).bg : _categoryBg(_catId);
    final catFg =
        cc != null ? categoryColorFor(cc.colorKey).fg : _categoryColor(_catId);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Transaction Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 60), // balance Close button
              ],
            ),
          ),

          // ── Main detail card ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  // Type + Amount
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: catBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    catIcon,
                                    size: 16,
                                    color: catFg,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _catName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          amountText,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  // Date
                  _DetailRow(
                    label: 'Date',
                    value: _formatDate(transaction.date),
                  ),

                  const Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFE5E7EB)),

                  // Account
                  _DetailRow(
                    label: 'Account',
                    value: transaction.accountName,
                  ),

                  // Tag (optional)
                  if (tagById(transaction.tag) != null) ...[
                    const Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFE5E7EB)),
                    _TagRow(tag: tagById(transaction.tag)!),
                  ],

                  // Payee (optional)
                  if (transaction.payee.isNotEmpty) ...[
                    const Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFE5E7EB)),
                    _DetailRow(
                      label: 'Payee',
                      value: transaction.payee,
                    ),
                  ],

                  // Memo (optional)
                  if (transaction.memo.isNotEmpty) ...[
                    const Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFE5E7EB)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Text(
                            'Memo',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Flexible(
                            child: Text(
                              transaction.memo,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Change category (fix a mis-detected one) ──
                  if (!isTransfer) ...[
                    const Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFE5E7EB)),
                    InkWell(
                      onTap: _pickCategory,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const Text(
                              'Category',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF9CA3AF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: catBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(catIcon, size: 13, color: catFg),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _catName,
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(Icons.chevron_right,
                                size: 18, color: Color(0xFF2E7D32)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Edit button (not for transfers — they are two linked rows) ──
          if (!isTransfer) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: onEdit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Edit Transaction',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ── Delete button ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete Transaction',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────

  String _formatAmount(double amount) {
    final n = amount.toInt();
    final s = n.toString();
    if (s.length <= 3) return '$s.00';
    if (s.length <= 5) {
      return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}.00';
    }
    return '${s.substring(0, s.length - 5)},${s.substring(s.length - 5, s.length - 3)},${s.substring(s.length - 3)}.00';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final month = months[date.month - 1];
    final year = date.year;
    final h = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final min = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour < 12 ? 'AM' : 'PM';
    return '$day $month $year at $h:$min $ampm';
  }

  IconData _categoryIcon(String catId) => switch (catId) {
        'food_drink' => Icons.restaurant_rounded,
        'transport' => Icons.directions_car_rounded,
        'shopping' => Icons.shopping_bag_rounded,
        'health' => Icons.favorite_rounded,
        'entertainment' => Icons.movie_rounded,
        'bills' => Icons.receipt_rounded,
        'education' => Icons.school_rounded,
        'travel' => Icons.flight_rounded,
        'groceries' => Icons.shopping_cart_rounded,
        'emi' => Icons.home_rounded,
        _ => Icons.more_horiz_rounded,
      };

  Color _categoryColor(String catId) => switch (catId) {
        'food_drink' => const Color(0xFFF97316),
        'transport' => const Color(0xFF3B82F6),
        'shopping' => const Color(0xFF14B8A6),
        'health' => const Color(0xFFEF4444),
        'entertainment' => const Color(0xFF7C3AED),
        'bills' => const Color(0xFF6366F1),
        'education' => const Color(0xFF6366F1),
        'travel' => const Color(0xFF3B82F6),
        'groceries' => const Color(0xFF10B981),
        'emi' => const Color(0xFF8B5CF6),
        _ => const Color(0xFF6B7280),
      };

  Color _categoryBg(String catId) => switch (catId) {
        'food_drink' => const Color(0xFFFFF7ED),
        'transport' => const Color(0xFFEFF6FF),
        'shopping' => const Color(0xFFCCFBF1),
        'health' => const Color(0xFFFFF1F2),
        'entertainment' => const Color(0xFFF5F3FF),
        'bills' => const Color(0xFFEEF2FF),
        'education' => const Color(0xFFEEF2FF),
        'travel' => const Color(0xFFEFF6FF),
        'groceries' => const Color(0xFFE6FAF2),
        'emi' => const Color(0xFFF5F3FF),
        _ => const Color(0xFFF3F4F6),
      };
}

// ── Simple label-value row ────────────────────────────────────
// ── Tag row with a pill badge ─────────────────────────────────
class _TagRow extends StatelessWidget {
  final TransactionTag tag;
  const _TagRow({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Tag',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          TagBadge(tag: tag),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
