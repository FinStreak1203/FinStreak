import 'package:flutter/material.dart';

class CategoryStat {
  final String categoryId;
  final String name;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final double amount;
  final int transactionCount;
  final double percentage;

  const CategoryStat({
    required this.categoryId,
    required this.name,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.amount,
    required this.transactionCount,
    required this.percentage,
  });
}

enum InsightCardType { pattern, forecast, behavior, saving }

class InsightCard {
  final String title;
  final String body;
  final InsightCardType type;

  const InsightCard({
    required this.title,
    required this.body,
    required this.type,
  });
}

class CategoryStyle {
  final Color color;
  final IconData icon;
  final Color bgColor;

  const CategoryStyle({
    required this.color,
    required this.icon,
    required this.bgColor,
  });
}

final categoryStyleMap = <String, CategoryStyle>{
  'food_drink': CategoryStyle(
    color: const Color(0xFFEF4444),
    icon: Icons.restaurant_rounded,
    bgColor: const Color(0xFFFFEDED),
  ),
  'travel': CategoryStyle(
    color: const Color(0xFF3B82F6),
    icon: Icons.flight_rounded,
    bgColor: const Color(0xFFEFF6FF),
  ),
  'emi': CategoryStyle(
    color: const Color(0xFF8B5CF6),
    icon: Icons.home_rounded,
    bgColor: const Color(0xFFF5F3FF),
  ),
  'shopping': CategoryStyle(
    color: const Color(0xFF14B8A6),
    icon: Icons.shopping_bag_rounded,
    bgColor: const Color(0xFFCCFBF1),
  ),
  'groceries': CategoryStyle(
    color: const Color(0xFF2E7D32),
    icon: Icons.shopping_cart_rounded,
    bgColor: const Color(0xFFF0FDF4),
  ),
  'bills': CategoryStyle(
    color: const Color(0xFFF97316),
    icon: Icons.receipt_rounded,
    bgColor: const Color(0xFFFFF7ED),
  ),
  'other': CategoryStyle(
    color: const Color(0xFF6B7280),
    icon: Icons.more_horiz_rounded,
    bgColor: const Color(0xFFF3F4F6),
  ),
};
