import 'package:flutter/material.dart';
import '../../core/constants/transaction_tags.dart';

/// Small rounded pill badge showing a transaction's tag (emoji + label).
class TagBadge extends StatelessWidget {
  final TransactionTag tag;
  final double fontSize;

  const TagBadge({super.key, required this.tag, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
      ),
      child: Text(
        '${tag.emoji} ${tag.label}',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
