import 'package:flutter/material.dart';
import '../../core/theme/finella_colors.dart';

class LockedAiCard extends StatelessWidget {
  final String teaserText;
  final VoidCallback onUpgrade;

  const LockedAiCard({
    super.key,
    required this.teaserText,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 14, color: FinellaColors.textGray),
              const SizedBox(width: 6),
              const Text(
                'FinStreak AI Insight',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: FinellaColors.goldLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Blurred lines
          Container(
            height: 7,
            decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 4),
          FractionallySizedBox(
            widthFactor: 0.65,
            alignment: Alignment.centerLeft,
            child: Container(
              height: 7,
              decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 8),

          // Teaser
          Text(
            teaserText,
            style: const TextStyle(
              fontSize: 9,
              color: Color(0xFF6B7280),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Fix 6: Full-width large button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: onUpgrade,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_open_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Unlock FinStreak Premium',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
