import 'package:flutter/material.dart';

class MilestoneBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final double percent;
  final bool reached;

  const MilestoneBadge({
    super.key,
    required this.emoji,
    required this.label,
    required this.percent,
    required this.reached,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: reached ? const Color(0xFFF0FDF4) : const Color(0xFFF3F4F6),
            border: Border.all(
              color: reached ? const Color(0xFF2E7D32) : const Color(0xFFD1D5DB),
              width: 1.5,
            ),
          ),
          child: Center(
            child: Text(
              reached ? emoji : '${percent.toInt()}%',
              style: TextStyle(
                fontSize: reached ? 20 : 9,
                fontWeight: FontWeight.w700,
                color: reached ? null : const Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: reached ? const Color(0xFF2E7D32) : const Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}
