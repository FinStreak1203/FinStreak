import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../models/reconcile_result.dart';
import 'reconcile_screen.dart' show formatRupee;

const _kDark = Color(0xFF1A3C34);
const _kGreen = Color(0xFF2E7D32);
const _kBg = Color(0xFFF7FAF4);

class ReconcileSuccessScreen extends StatefulWidget {
  final ReconcileResult result;
  const ReconcileSuccessScreen({super.key, required this.result});

  @override
  State<ReconcileSuccessScreen> createState() => _ReconcileSuccessScreenState();
}

class _ReconcileSuccessScreenState extends State<ReconcileSuccessScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => context.go(RouteNames.home),
        ),
        title: const Text('Reconciliation Successful',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32))),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              const SizedBox(height: 12),
              const _SuccessBadge(),
              const SizedBox(height: 24),
              const Center(
                child: Text('Great Job! 🎉',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _kGreen)),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'You have successfully reconciled\nyour accounts for today.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(height: 24),
              _balanceCard(r),
              const SizedBox(height: 14),
              _streakCard(r),
              const SizedBox(height: 14),
              _consistencyCard(),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go(RouteNames.home),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kGreen,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Back to Home',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => context.go(RouteNames.activity),
                  child: const Text("View Today's Summary",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kGreen)),
                ),
              ),
            ],
          ),
          // Confetti bursts from the top-center.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.25,
              colors: const [
                _kGreen,
                Color(0xFFFBBF24),
                Color(0xFF60A5FA),
                Color(0xFFF87171),
                Color(0xFF34D399),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard(ReconcileResult r) {
    return _card(
      Column(
        children: [
          _row('Expected Balance', formatRupee(r.expected),
              valueColor: const Color(0xFF6B7280)),
          const SizedBox(height: 12),
          _row('Actual Balance', formatRupee(r.actual),
              valueColor: _kGreen),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          _row('Difference', formatRupee(r.difference),
              labelBold: true, valueColor: _kGreen, valueBold: true),
        ],
      ),
    );
  }

  Widget _streakCard(ReconcileResult r) {
    return _card(
      Column(
        children: [
          const Text('R-Streak Increased!',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _kGreen)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _streakNum('🔥', r.previousStreak),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 22),
                child: Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF9CA3AF)),
              ),
              _streakNum('', r.newStreak, highlight: true),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Keep your money streak alive! 🔥',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280))),
        ],
      ),
    );
  }

  Widget _streakNum(String emoji, int days, {bool highlight = false}) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 4),
            ],
            Text('$days',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    color: highlight ? _kGreen : const Color(0xFF111827))),
          ],
        ),
        Text('Days',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: highlight ? _kGreen : const Color(0xFF6B7280))),
      ],
    );
  }

  Widget _consistencyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
                color: _kGreen, shape: BoxShape.circle),
            child: const Icon(Icons.trending_up_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Consistency is the key',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827))),
                SizedBox(height: 2),
                Text('Amazing! You are one step closer to financial freedom.',
                    style: TextStyle(
                        fontSize: 12, height: 1.4, color: Color(0xFF4B5563))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool labelBold = false, bool valueBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: labelBold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF374151))),
        Text(value,
            style: TextStyle(
                fontSize: valueBold ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: valueColor ?? const Color(0xFF111827))),
      ],
    );
  }

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEFF1F0)),
        ),
        child: child,
      );
}

// ── Animated R badge with checkmark ───────────────────────────
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (_, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: SizedBox(
        height: 150,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGreen.withValues(alpha: 0.10),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: const BoxDecoration(
                  color: _kDark, shape: BoxShape.circle),
              child: const Center(
                child: Text('R⚡',
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
            Positioned(
              bottom: 18,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: _kBg, width: 3),
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
