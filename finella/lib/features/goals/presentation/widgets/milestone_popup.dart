import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

// ══════════════════════════════════════════════════════════════
// MilestoneData
// ══════════════════════════════════════════════════════════════
class MilestoneData {
  final String name;
  final int percentage;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String emoji;
  final String motivationalText;

  const MilestoneData({
    required this.name,
    required this.percentage,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.emoji,
    required this.motivationalText,
  });
}

const List<MilestoneData> milestones = [
  MilestoneData(
    name: 'Bronze',
    percentage: 10,
    color: Color(0xFFCD7F32),
    bgColor: Color(0xFFFDF0E0),
    icon: Icons.check_rounded,
    emoji: '🥉',
    motivationalText: 'Great start! Keep saving!',
  ),
  MilestoneData(
    name: 'Silver',
    percentage: 20,
    color: Color(0xFFA8A8A8),
    bgColor: Color(0xFFF5F5F5),
    icon: Icons.check_rounded,
    emoji: '🥈',
    motivationalText: 'Amazing progress! You are building great habits!',
  ),
  MilestoneData(
    name: 'Gold',
    percentage: 50,
    color: Color(0xFFD4AF37),
    bgColor: Color(0xFFFEF9C3),
    icon: Icons.star_rounded,
    emoji: '⭐',
    motivationalText: 'You are halfway there! Keep going!',
  ),
  MilestoneData(
    name: 'Diamond',
    percentage: 90,
    color: Color(0xFF60A5FA),
    bgColor: Color(0xFFEFF6FF),
    icon: Icons.diamond_outlined,
    emoji: '💎',
    motivationalText: 'Almost there! Just a little more to go!',
  ),
  MilestoneData(
    name: 'Trophy',
    percentage: 100,
    color: Color(0xFF2E7D32),
    bgColor: Color(0xFFF0FDF4),
    icon: Icons.emoji_events_rounded,
    emoji: '🏆',
    motivationalText: 'GOAL COMPLETE! You did it! Amazing achievement!',
  ),
];

// ── Public helper: check thresholds & auto-trigger popup ──────
void checkAndShowMilestone({
  required BuildContext context,
  required String goalName,
  required double oldSaved,
  required double newSaved,
  required double targetAmount,
}) {
  if (targetAmount <= 0) return;
  final oldPct = (oldSaved / targetAmount) * 100;
  final newPct = (newSaved / targetAmount) * 100;

  for (final milestone in milestones) {
    if (oldPct < milestone.percentage && newPct >= milestone.percentage) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (context.mounted) {
          showMilestonePopup(
            context: context,
            goalName: goalName,
            savedAmount: newSaved,
            targetAmount: targetAmount,
            milestone: milestone,
            userName: 'Priya', // TODO: pull from user profile
          );
        }
      });
      break; // show only one popup at a time
    }
  }
}

// ── Public entry point ────────────────────────────────────────
Future<void> showMilestonePopup({
  required BuildContext context,
  required String goalName,
  required double savedAmount,
  required double targetAmount,
  required MilestoneData milestone,
  required String userName,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => MilestonePopupDialog(
      goalName: goalName,
      savedAmount: savedAmount,
      targetAmount: targetAmount,
      milestone: milestone,
      userName: userName,
      onShare: () => _shareAchievement(goalName, milestone, savedAmount),
      onContinue: () => Navigator.pop(ctx),
    ),
  );
}

// ── Share helper ──────────────────────────────────────────────
void _shareAchievement(
  String goalName,
  MilestoneData milestone,
  double savedAmount,
) {
  final text = 'I just reached the ${milestone.emoji} ${milestone.name} '
      'milestone for my $goalName goal on FinStreak! '
      'Saved ₹${_fmt(savedAmount)} so far. '
      '#FinStreak #SavingsGoal #FinancialFreedom';
  Share.share(text);
}

// ══════════════════════════════════════════════════════════════
// MilestonePopupDialog
// ══════════════════════════════════════════════════════════════
class MilestonePopupDialog extends StatefulWidget {
  final String goalName;
  final double savedAmount;
  final double targetAmount;
  final MilestoneData milestone;
  final String userName;
  final VoidCallback onShare;
  final VoidCallback onContinue;

  const MilestonePopupDialog({
    super.key,
    required this.goalName,
    required this.savedAmount,
    required this.targetAmount,
    required this.milestone,
    required this.userName,
    required this.onShare,
    required this.onContinue,
  });

  @override
  State<MilestonePopupDialog> createState() => _MilestonePopupDialogState();
}

class _MilestonePopupDialogState extends State<MilestonePopupDialog>
    with TickerProviderStateMixin {
  // Medal bounce-in
  late AnimationController _medalController;
  late Animation<double> _medalScale;

  // Glow pulse
  late AnimationController _glowController;
  late Animation<double> _glowOpacity;

  // Confetti
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();

    // 1. Medal scales in with elastic bounce
    _medalController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..forward();

    _medalScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _medalController, curve: Curves.elasticOut),
    );

    // 2. Glow pulses continuously after medal appears
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat(reverse: true);

    _glowOpacity = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // 3. Confetti plays once
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3))..play();
  }

  @override
  void dispose() {
    _medalController.dispose();
    _glowController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.milestone;
    final pct =
        (widget.savedAmount / widget.targetAmount * 100).clamp(0.0, 100.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Medal + confetti area ──────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                width: double.infinity,
                height: 180,
                color: m.bgColor,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Confetti bursts from center-top
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConfettiWidget(
                        confettiController: _confettiController,
                        blastDirectionality: BlastDirectionality.explosive,
                        blastDirection: math.pi / 2, // downward bias
                        numberOfParticles: 28,
                        maxBlastForce: 24,
                        minBlastForce: 10,
                        gravity: 0.25,
                        shouldLoop: false,
                        colors: const [
                          Color(0xFF2E7D32),
                          Color(0xFFD4AF37),
                          Color(0xFFCD7F32),
                          Color(0xFF60A5FA),
                          Color(0xFFA8A8A8),
                          Colors.white,
                        ],
                      ),
                    ),

                    // Animated glow ring behind medal
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (_, _) => Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: m.color.withValues(
                                  alpha: _glowOpacity.value),
                              blurRadius: 32,
                              spreadRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Medal circle — bounces in
                    ScaleTransition(
                      scale: _medalScale,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              m.color.withValues(alpha: 0.85),
                              m.color,
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white,
                            width: 3.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: m.color.withValues(alpha: 0.4),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${m.percentage}%',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Text content ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                children: [
                  // Congratulations
                  Text(
                    'Congratulations, ${widget.userName}!',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Milestone name
                  Text(
                    '${m.emoji}  You reached ${m.name.toUpperCase()} milestone!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: m.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),

                  // Goal name + %
                  Text(
                    '${widget.goalName} · ${pct.toInt()}% complete',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Amount saved
                  Text(
                    '₹${_fmt(widget.savedAmount)} saved!',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E7D32),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Journey row ───────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _JourneyBadge(
                        color: const Color(0xFFCD7F32),
                        icon: Icons.check_rounded,
                        isCompleted: pct >= 10,
                        isCurrent: m.name == 'Bronze',
                        isLocked: false,
                      ),
                      _JourneyLine(isCompleted: pct >= 20),
                      _JourneyBadge(
                        color: const Color(0xFFA8A8A8),
                        icon: Icons.check_rounded,
                        isCompleted: pct >= 20,
                        isCurrent: m.name == 'Silver',
                        isLocked: false,
                      ),
                      _JourneyLine(isCompleted: pct >= 50),
                      _JourneyBadge(
                        color: const Color(0xFFD4AF37),
                        icon: Icons.star_rounded,
                        isCompleted: pct >= 50,
                        isCurrent: m.name == 'Gold',
                        isLocked: false,
                      ),
                      _JourneyLine(isCompleted: pct >= 90),
                      _JourneyBadge(
                        color: const Color(0xFF60A5FA),
                        icon: Icons.diamond_outlined,
                        isCompleted: pct >= 90,
                        isCurrent: m.name == 'Diamond',
                        isLocked: pct < 90 && m.name != 'Diamond',
                      ),
                      _JourneyLine(isCompleted: pct >= 100),
                      _JourneyBadge(
                        color: const Color(0xFF2E7D32),
                        icon: Icons.emoji_events_rounded,
                        isCompleted: pct >= 100,
                        isCurrent: m.name == 'Trophy',
                        isLocked: pct < 100 && m.name != 'Trophy',
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Motivational text
                  Text(
                    m.motivationalText,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 20),

                  // ── Buttons ───────────────────────────────
                  Row(
                    children: [
                      // Share
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: widget.onShare,
                          icon: const Icon(Icons.share_outlined, size: 16),
                          label: const Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(
                                color: Color(0xFF2E7D32), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Continue
                      Expanded(
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          child: const Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Journey badge ─────────────────────────────────────────────
class _JourneyBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLocked;

  const _JourneyBadge({
    required this.color,
    required this.icon,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 50.0 : 38.0;
    final iconSize = isCurrent ? 22.0 : 17.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (isCompleted || isCurrent) ? color : const Color(0xFFF3F4F6),
        border: Border.all(
          color: (isCompleted || isCurrent) ? color : const Color(0xFFE5E7EB),
          width: isCurrent ? 3 : 1.5,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ]
            : null,
      ),
      child: Icon(
        isLocked ? Icons.lock_outline_rounded : icon,
        size: iconSize,
        color: (isCompleted || isCurrent) ? Colors.white : const Color(0xFFD1D5DB),
      ),
    );
  }
}

// ── Journey line ──────────────────────────────────────────────
class _JourneyLine extends StatelessWidget {
  final bool isCompleted;
  const _JourneyLine({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2.5,
      color: isCompleted ? const Color(0xFF2E7D32) : const Color(0xFFE5E7EB),
    );
  }
}

// ── Amount formatter ──────────────────────────────────────────
String _fmt(double amount) {
  final n = amount.toInt();
  final s = n.toString();
  if (s.length <= 3) return s;
  if (s.length <= 5) {
    return '${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
  }
  return '${s.substring(0, s.length - 5)},'
      '${s.substring(s.length - 5, s.length - 3)},'
      '${s.substring(s.length - 3)}';
}
