import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../transactions/presentation/category_picker_sheet.dart';
import '../viewmodel/budgets_view_model.dart';
import 'widgets/new_budget_sheet.dart';

/// Budgets overview screen.
///
/// Standalone (root-navigator) route opened from Settings → Budget, so it has
/// no bottom tab bar. Data is sourced reactively from the database via
/// [budgetsStateProvider] (MVVM: this widget is the View).
class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  void _openBudgetSheet(BuildContext context, {Budget? budget}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NewBudgetSheet(budget: budget),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(budgetsStateProvider);
    final monthNotifier = ref.read(budgetMonthProvider.notifier);

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
          'Budgets',
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
              onPressed: () => _openBudgetSheet(context),
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
      body: Column(
        children: [
          // ── Month selector ──────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MonthArrow(
                  icon: Icons.chevron_left,
                  onTap: monthNotifier.previousMonth,
                ),
                Text(
                  '${_months[state.month.month]} ${state.month.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                _MonthArrow(
                  icon: Icons.chevron_right,
                  onTap: monthNotifier.nextMonth,
                ),
              ],
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  )
                : state.budgets.isEmpty
                    ? const _EmptyState()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _SummaryCard(
                            totalLimit: state.totalLimit,
                            totalSpent: state.totalSpent,
                          ),
                          const SizedBox(height: 16),
                          for (final b in state.budgets) ...[
                            _BudgetTile(
                              summary: b,
                              onTap: () => _openBudgetSheet(
                                context,
                                budget: b.budget,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Money helper (Indian grouping) ────────────────────────────
String _money(double value) {
  final negative = value < 0;
  var intPart = value.abs().toStringAsFixed(0);
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
  return '${negative ? '-' : ''}₹$grouped';
}

CategoryItem? _categoryItem(String id) {
  for (final c in allCategories) {
    if (c.id == id) return c;
  }
  return null;
}

// ── Month arrow button ────────────────────────────────────────
class _MonthArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MonthArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Icon(icon, size: 22, color: const Color(0xFF374151)),
        ),
      ),
    );
  }
}

// ── Summary card ──────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final double totalLimit;
  final double totalSpent;
  const _SummaryCard({required this.totalLimit, required this.totalSpent});

  @override
  Widget build(BuildContext context) {
    final remaining = totalLimit - totalSpent;
    final progress =
        totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;
    final over = totalSpent > totalLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A3D2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total Budget',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFFB7C9C1),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_money(totalSpent)} / ${_money(totalLimit)}',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.toDouble(),
              minHeight: 8,
              backgroundColor: const Color(0xFF1C5443),
              valueColor: AlwaysStoppedAnimation(
                over ? const Color(0xFFF87171) : const Color(0xFF4ADE80),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            over
                ? '${_money(-remaining)} over budget'
                : '${_money(remaining)} remaining',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: over ? const Color(0xFFF87171) : const Color(0xFFB7C9C1),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Budget tile ───────────────────────────────────────────────
class _BudgetTile extends StatelessWidget {
  final BudgetSummary summary;
  final VoidCallback onTap;
  const _BudgetTile({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = _categoryItem(summary.categoryId);
    final over = summary.isOverBudget;
    final categoryColor = cat?.iconColor ?? const Color(0xFF2E7D32);
    final barColor = over ? const Color(0xFFEF4444) : categoryColor;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF1F0)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cat?.bgColor ?? const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat?.icon ?? Icons.category_rounded,
                      color: cat?.iconColor ?? const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      summary.categoryName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    '${_money(summary.spent)} / ${_money(summary.limit)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  over
                      ? '${_money(-summary.remaining)} over budget'
                      : '${_money(summary.remaining)} left',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: over
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty state (matches the design) ──────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0EC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 44,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No budgets yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap "+ New" to create your first budget',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}
