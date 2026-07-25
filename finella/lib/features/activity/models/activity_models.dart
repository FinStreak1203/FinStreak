import 'package:flutter/material.dart';

class TransactionDisplay {
  final String id;
  final String name;
  final String category;
  final String account;
  final String dateLabel;
  final DateTime date;
  final double amount;
  final bool isIncome;
  final Color iconBg;
  final IconData icon;
  final bool isTransfer;
  final String? transferTo; // destination account name (transfers only)

  /// Provenance for the row badge: 'sms', 'email', or null (manual).
  final String? source;

  /// ISO currency code — drives the amount symbol ($ for USD, else ₹).
  final String currency;

  const TransactionDisplay({
    required this.id,
    required this.name,
    required this.category,
    required this.account,
    required this.dateLabel,
    required this.date,
    required this.amount,
    required this.isIncome,
    required this.iconBg,
    required this.icon,
    this.isTransfer = false,
    this.transferTo,
    this.source,
    this.currency = 'INR',
  });
}

class RecurringPayment {
  final String name;
  final String description;
  final double amount;
  final String nextPayment;
  final Color brandColor;
  final String brandInitial;

  const RecurringPayment({
    required this.name,
    required this.description,
    required this.amount,
    required this.nextPayment,
    required this.brandColor,
    required this.brandInitial,
  });
}

enum AiAlertType { anomaly, subscription, duplicate }

class AiAlert {
  final AiAlertType type;
  final String title;
  final String body;

  const AiAlert({
    required this.type,
    required this.title,
    required this.body,
  });
}
