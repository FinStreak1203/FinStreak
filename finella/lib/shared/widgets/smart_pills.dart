import 'package:flutter/material.dart';

class SmartPills extends StatelessWidget {
  final String savedAmount;
  final int goalsActive;
  final int streakDays;

  const SmartPills({
    super.key,
    required this.savedAmount,
    required this.goalsActive,
    required this.streakDays,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _Pill(
            label: '$savedAmount Saved',
            bg: const Color(0xFF16A34A),
            textColor: Colors.white,
          ),
          const SizedBox(width: 6),
          _Pill(
            label: '$goalsActive Goals Active',
            bg: const Color(0xFF2563EB),
            textColor: Colors.white,
          ),
          const SizedBox(width: 6),
          _Pill(
            label: '$streakDays Day Streak',
            bg: const Color(0xFFEA7316),
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.bg,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
