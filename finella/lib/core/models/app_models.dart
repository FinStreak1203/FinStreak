import 'package:flutter/material.dart';

class SpendingCategory {
  final String name;
  final double amount;
  final Color color;
  final int percentage;
  final bool isOnTrack;

  const SpendingCategory({
    required this.name,
    required this.amount,
    required this.color,
    required this.percentage,
    this.isOnTrack = false,
  });
}

class TransactionData {
  final String id;
  final String name;
  final String category;
  final String accountName;
  final double amount;
  final bool isExpense;
  final DateTime date;
  final Color categoryColor;
  final IconData categoryIcon;
  final bool isTransfer;
  final String? transferTo; // destination account name (transfers only)

  const TransactionData({
    required this.id,
    required this.name,
    required this.category,
    required this.accountName,
    required this.amount,
    required this.isExpense,
    required this.date,
    required this.categoryColor,
    required this.categoryIcon,
    this.isTransfer = false,
    this.transferTo,
  });
}

class GoalData {
  final String id;
  final String name;
  final double saved;
  final double target;
  final String? aiTip;

  const GoalData({
    required this.id,
    required this.name,
    required this.saved,
    required this.target,
    this.aiTip,
  });
}

enum InsightType { warn, save, predict, goal }

class AiInsight {
  final InsightType type;
  final String title;
  final String body;

  const AiInsight({
    required this.type,
    required this.title,
    required this.body,
  });
}
