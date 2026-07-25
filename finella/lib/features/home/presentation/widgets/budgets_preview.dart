import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/finella_colors.dart';
import '../../../budgets/viewmodel/budgets_view_model.dart';
import '../../../transactions/presentation/category_picker_sheet.dart';

/// Compact "Budgets" section for the home screen — shows up to 3 budgets
/// with their progress, and a "See All →" link to the full Budgets screen.
class BudgetsPreview extends StatelessWidget {
  final List<BudgetSummary> budgets;
  final VoidCallback onSeeAll;
  final void Function(Budget budget)? onTap;

  const BudgetsPreview({
    super.key,
    required this.budgets,
    required this.onSeeAll,
    this.onTap,
  });

  static String _money(double v) {
    final neg = v < 0;
    var s = v.abs().toStringAsFixed(0);
    if (s.length > 3) {
      final last3 = s.substring(s.length - 3);
      var rest = s.substring(0, s.length - 3);
      final buf = StringBuffer();
      while (rest.length > 2) {
        buf.write(',${rest.substring(rest.length - 2)}');
        rest = rest.substring(0, rest.length - 2);
      }
      s = '$rest$buf,$last3';
    }
    return '${neg ? '-' : ''}₹$s';
  }

  static CategoryItem? _cat(String id) {
    for (final c in allCategories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Budgets',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: FinellaColors.textDark)),
              GestureDetector(
                onTap: onSeeAll,
                child: const Text('All →',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: FinellaColors.primary)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(
            children: [
              for (final b in budgets)
                _BudgetRow(
                  summary: b,
                  onTap: onTap != null ? () => onTap!(b.budget) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BudgetRow extends StatelessWidget {
  final BudgetSummary summary;
  final VoidCallback? onTap;
  const _BudgetRow({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = BudgetsPreview._cat(summary.categoryId);
    final over = summary.isOverBudget;
    final categoryColor = cat?.iconColor ?? const Color(0xFF2E7D32);
    final barColor = over ? const Color(0xFFEF4444) : categoryColor;

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
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cat?.bgColor ?? const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat?.icon ?? Icons.category_rounded,
                      size: 18,
                      color: cat?.iconColor ?? const Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.categoryName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  Text(
                    '${BudgetsPreview._money(summary.spent)} / ${BudgetsPreview._money(summary.limit)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFF3F4F6),
                  valueColor: AlwaysStoppedAnimation(barColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
