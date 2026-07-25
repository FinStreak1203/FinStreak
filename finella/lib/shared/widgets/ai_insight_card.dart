import 'package:flutter/material.dart';
import '../../core/models/app_models.dart';

class AiInsightCard extends StatelessWidget {
  final InsightType type;
  final String title;
  final String body;

  const AiInsightCard({
    super.key,
    required this.type,
    required this.title,
    required this.body,
  });

  Color get _borderColor => switch (type) {
        InsightType.warn    => const Color(0xFFF97316),
        InsightType.save    => const Color(0xFF22C55E),
        InsightType.predict => const Color(0xFFD4AF37),
        InsightType.goal    => const Color(0xFF2E7D32),
      };

  Color get _iconBg => switch (type) {
        InsightType.warn    => const Color(0xFFFFF7ED),
        InsightType.save    => const Color(0xFFF0FDF4),
        InsightType.predict => const Color(0xFFFEFCE8),
        InsightType.goal    => const Color(0xFFF0FDF4),
      };

  IconData get _icon => switch (type) {
        InsightType.warn    => Icons.local_fire_department,
        InsightType.save    => Icons.lightbulb_outline,
        InsightType.predict => Icons.auto_awesome,
        InsightType.goal    => Icons.track_changes,
      };

  Color get _iconColor => switch (type) {
        InsightType.warn    => const Color(0xFFF97316),
        InsightType.save    => const Color(0xFF22C55E),
        InsightType.predict => const Color(0xFFD4AF37),
        InsightType.goal    => const Color(0xFF2E7D32),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFF3F4F6)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colored left accent bar — child widget, not border
          Container(width: 3, color: _borderColor),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: _iconBg, borderRadius: BorderRadius.circular(6)),
                    child: Icon(_icon, size: 13, color: _iconColor),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 1),
                        Text(body,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF6B7280),
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
