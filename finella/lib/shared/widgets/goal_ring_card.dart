import 'dart:math';
import 'package:flutter/material.dart';

class GoalRingCard extends StatelessWidget {
  final String name;
  final double savedAmount;
  final double targetAmount;
  final bool isPremium;
  final String? aiTip;

  const GoalRingCard({
    super.key,
    required this.name,
    required this.savedAmount,
    required this.targetAmount,
    required this.isPremium,
    this.aiTip,
  });

  String _fmtShort(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    final pct = targetAmount > 0 ? (savedAmount / targetAmount * 100).clamp(0, 100) : 0.0;
    final bronzeReached = pct >= 10;
    final silverReached = pct >= 20;
    final goldReached = pct >= 50;
    final diamondReached = pct >= 90;
    final trophyReached = pct >= 100;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CustomPaint(
              painter: _RingPainter(progress: pct / 100),
              child: Center(
                child: Text(
                  '${pct.toInt()}%',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            '${_fmtShort(savedAmount)} / ${_fmtShort(targetAmount)}',
            style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Badge(reached: bronzeReached, color: const Color(0xFFCD7F32)),
              const SizedBox(width: 2),
              _Badge(reached: silverReached, color: const Color(0xFFC0C0C0)),
              const SizedBox(width: 2),
              _Badge(reached: goldReached, color: const Color(0xFFD4AF37)),
              const SizedBox(width: 2),
              _Badge(reached: diamondReached, color: const Color(0xFF60A5FA)),
              const SizedBox(width: 2),
              _Badge(reached: trophyReached, color: const Color(0xFF2E7D32)),
            ],
          ),
          if (isPremium && aiTip != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                aiTip!,
                style: const TextStyle(fontSize: 9, color: Color(0xFF065F46), fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final bool reached;
  final Color color;

  const _Badge({required this.reached, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: reached ? color : Colors.transparent,
        border: Border.all(color: reached ? color : const Color(0xFFD1D5DB), width: 1.5),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;

  _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = min(cx, cy) - 5;

    final bgPaint = Paint()
      ..color = const Color(0xFFF3F4F6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, bgPaint);
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fgPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}
