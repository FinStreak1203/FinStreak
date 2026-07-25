import 'package:flutter/material.dart';
import '../../models/activity_models.dart';

class AiAlertRow extends StatelessWidget {
  final AiAlert alert;

  const AiAlertRow({super.key, required this.alert});

  Color get _borderColor => switch (alert.type) {
        AiAlertType.anomaly => const Color(0xFFEF4444),
        AiAlertType.subscription => const Color(0xFFD4AF37),
        AiAlertType.duplicate => const Color(0xFFF97316),
      };

  Color get _titleColor => switch (alert.type) {
        AiAlertType.anomaly => const Color(0xFFDC2626),
        AiAlertType.subscription => const Color(0xFFB45309),
        AiAlertType.duplicate => const Color(0xFFC2410C),
      };

  IconData get _icon => switch (alert.type) {
        AiAlertType.anomaly => Icons.warning_amber_rounded,
        AiAlertType.subscription => Icons.content_cut_rounded,
        AiAlertType.duplicate => Icons.copy_rounded,
      };

  Color get _iconColor => switch (alert.type) {
        AiAlertType.anomaly => const Color(0xFFEF4444),
        AiAlertType.subscription => const Color(0xFFD4AF37),
        AiAlertType.duplicate => const Color(0xFFF97316),
      };

  Color get _iconBg => switch (alert.type) {
        AiAlertType.anomaly => const Color(0xFFFFF1F2),
        AiAlertType.subscription => const Color(0xFFFEFCE8),
        AiAlertType.duplicate => const Color(0xFFFFF7ED),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          Container(width: 3, color: _borderColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _iconBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_icon, color: _iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _titleColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.body,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                            height: 1.4,
                          ),
                        ),
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
