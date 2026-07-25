import 'package:flutter/material.dart';
import '../../core/theme/finella_colors.dart';

class StreakRow extends StatelessWidget {
  final int currentDay;
  final int totalDays;
  final bool isPremium;
  final VoidCallback? onTap;

  const StreakRow({
    super.key,
    required this.currentDay,
    required this.totalDays,
    required this.isPremium,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            Text(
              'Day $currentDay of $totalDays',
              style: const TextStyle(
                color: FinellaColors.textLight,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Text('🔥', style: TextStyle(fontSize: 11)),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right,
                  size: 14, color: FinellaColors.textLight),
            ],
            const SizedBox(width: 6),
            _Pill(
              label: '$currentDay/$totalDays Days',
              bg: FinellaColors.greenLight,
              border: FinellaColors.greenBorder,
              textColor: FinellaColors.primary,
            ),
            if (isPremium) ...[
              const SizedBox(width: 6),
              _Pill(
                label: 'Premium Member',
                bg: FinellaColors.goldLight,
                border: FinellaColors.gold,
                textColor: const Color(0xFF92400E),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.bg,
    required this.border,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
