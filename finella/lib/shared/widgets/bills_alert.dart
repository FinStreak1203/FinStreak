import 'package:flutter/material.dart';

class BillsAlertCard extends StatelessWidget {
  final int billCount;
  final double totalAmount;
  final bool isPremium;
  final VoidCallback onReview;

  const BillsAlertCard({
    super.key,
    required this.billCount,
    required this.totalAmount,
    required this.isPremium,
    required this.onReview,
  });

  String _fmt(double v) =>
      v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,2})(?=(\d{2})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFFDE68A)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$billCount bills due this week — ₹${_fmt(totalAmount)} total',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF92400E),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onReview,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isPremium ? 'Pay' : 'Review',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
