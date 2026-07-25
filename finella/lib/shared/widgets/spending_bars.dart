import 'package:flutter/material.dart';
import '../../core/models/app_models.dart';
import '../../core/theme/finella_colors.dart';

class WeeklySpendingBars extends StatelessWidget {
  final double weeklyTotal;
  final List<SpendingCategory> categories;

  const WeeklySpendingBars({
    super.key,
    required this.weeklyTotal,
    required this.categories,
  });

  String _fmt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FinellaColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "This Week's Spending",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: FinellaColors.textDark),
              ),
              Text(
                '₹${_fmt(weeklyTotal)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: FinellaColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...categories.map((cat) => _CategoryRow(category: cat)),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final SpendingCategory category;

  const _CategoryRow({required this.category});

  String _fmt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: category.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          // name — fixed 72px so all bars start at the same X
          SizedBox(
            width: 72,
            child: Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: FinellaColors.textDark, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          // percentage — fixed 36px right-aligned
          SizedBox(
            width: 36,
            child: Text(
              '${category.percentage}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: FinellaColors.textGray, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          // progress bar — expands to fill remaining space
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: category.percentage / 100,
                backgroundColor: const Color(0xFFF3F4F6),
                valueColor: AlwaysStoppedAnimation<Color>(category.color),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // amount — fixed 48px right-aligned
          SizedBox(
            width: 48,
            child: Text(
              '₹${_fmt(category.amount)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: FinellaColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}
