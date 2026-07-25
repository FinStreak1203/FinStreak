import 'package:flutter/material.dart';
import '../../core/theme/finella_colors.dart';

class BalanceHeroCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  final double dailyChange;
  final bool isPremium;
  final int? aiScore;
  final String? prediction;

  const BalanceHeroCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    required this.dailyChange,
    required this.isPremium,
    this.aiScore,
    this.prediction,
  });

  String _fmt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Row 1: label + AI score badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "TODAY'S BALANCE",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              if (isPremium && aiScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: FinellaColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$aiScore/100',
                        style: const TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Text(
                        'AI Score',
                        style: TextStyle(
                          color: Color(0xFF78350F),
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 2: balance amount
          Text(
            '₹${_fmt(balance)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),

          // Row 2b: daily change
          Text(
            '${dailyChange >= 0 ? '+' : ''}₹${_fmt(dailyChange.abs())} since yesterday',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4ADE80),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Fix 5: horizontal divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.20),
            margin: const EdgeInsets.symmetric(vertical: 10),
          ),

          // Row 3: income | divider | spent (Fix 4: vertical divider)
          Row(
            children: [
              Expanded(child: _IncomeExpenseCol(label: 'Income', amount: income, isIncome: true)),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.25),
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(child: _IncomeExpenseCol(label: 'Spent', amount: expense, isIncome: false)),
            ],
          ),

          // Row 4: prediction (premium only)
          if (isPremium && prediction != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white70, size: 12),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      prediction!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeExpenseCol extends StatelessWidget {
  final String label;
  final double amount;
  final bool isIncome;

  const _IncomeExpenseCol({
    required this.label,
    required this.amount,
    required this.isIncome,
  });

  String _fmt(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? const Color(0xFF4ADE80) : const Color(0xFFF87171);
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: color,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w600)),
              Text(
                '₹${_fmt(amount)}',
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
