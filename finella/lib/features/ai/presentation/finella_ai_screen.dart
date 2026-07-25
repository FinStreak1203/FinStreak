import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/finella_colors.dart';
import 'ai_alerts_screen.dart';
import 'ai_chat_screen.dart';

// ── Main screen ───────────────────────────────────────────────
class FinellaAiScreen extends ConsumerStatefulWidget {
  const FinellaAiScreen({super.key});

  @override
  ConsumerState<FinellaAiScreen> createState() => _FinellaAiScreenState();
}

class _FinellaAiScreenState extends ConsumerState<FinellaAiScreen> {
  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(isPremiumProvider);
    return isPremium ? const _PremiumWelcomeScreen() : const _FreeLockScreen();
  }
}

// ══════════════════════════════════════════════════════════════
// FREE USER SCREEN
// ══════════════════════════════════════════════════════════════
class _FreeLockScreen extends ConsumerWidget {
  const _FreeLockScreen();

  static const _lockedQuestions = [
    'How much can I save this month?',
    'Can I afford a ₹20,000 EMI?',
    'Where am I overspending most?',
    'Should I start a SIP now?',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Finella AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.auto_awesome, color: FinellaColors.gold, size: 18),
          ],
        ),
        centerTitle: false,
        actions: const [_BellButton()],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 28),
            const _RobotAvatar(),
            const SizedBox(height: 24),
            const Text(
              'Your AI Financial Coach',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ask anything about your money.\nGet smart, personalized answers instantly.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            ..._lockedQuestions.map(
              (q) => _LockedQuestionCard(
                text: q,
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => AiChatScreen(initialQuestion: q),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(RouteNames.premium),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Unlock Finella AI — ₹199/month',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Cancel anytime · 7-day free trial',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF9CA3AF),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _LockedQuestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _LockedQuestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline_rounded,
                color: Color(0xFFD1D5DB), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}

class _RobotAvatar extends StatelessWidget {
  const _RobotAvatar();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 90,
                height: 78,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _RobotEye(),
                        const SizedBox(width: 16),
                        _RobotEye(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: 36,
                      height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF2E7D32),
                          width: 2.5,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(14),
                          bottomRight: Radius.circular(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 18,
                child:
                    Container(width: 3, height: 16, color: Colors.white),
              ),
              Positioned(
                top: 12,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child:
              const Icon(Icons.lock_rounded, color: Colors.white, size: 16),
        ),
      ],
    );
  }
}

class _RobotEye extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: const BoxDecoration(
          color: Color(0xFF2E7D32), shape: BoxShape.circle),
    );
  }
}

// ── Shared bell button (used in both free + premium AppBars) ──
class _BellButton extends StatelessWidget {
  const _BellButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const AiAlertsScreen(),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Stack(
          children: [
            const Center(
              child: Icon(
                Icons.notifications_outlined,
                color: Color(0xFF374151),
                size: 20,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PREMIUM WELCOME SCREEN
// (Replaces inline chat — all chat happens in AiChatScreen)
// ══════════════════════════════════════════════════════════════
class _PremiumWelcomeScreen extends StatelessWidget {
  const _PremiumWelcomeScreen();

  static const _suggestions = [
    'How can I save more?',
    'Analyze my spending',
    'Should I invest now?',
    'Help with EMI planning',
    'Show my goal progress',
    'Am I overspending?',
  ];

  void _openChat(BuildContext context, String question) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AiChatScreen(initialQuestion: question),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Finella AI',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            SizedBox(width: 6),
            Icon(Icons.auto_awesome, color: FinellaColors.gold, size: 18),
          ],
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9C3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    color: Color(0xFFD4AF37), size: 14),
                SizedBox(width: 4),
                Text(
                  'Premium',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const _BellButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),

            // Welcome hero
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi! I\'m Finella AI 👋',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Your personal financial coach.\nTap a question to start chatting.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Colors.white70,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // AI-generated spending insight for this month (loads on entry).
            const _AiInsightBanner(),

            const SizedBox(height: 8),

            const Text(
              'What would you like to know?',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),

            // Suggestion cards
            ..._suggestions.map(
              (q) => _SuggestionCard(
                text: q,
                onTap: () => _openChat(context, q),
              ),
            ),

            const SizedBox(height: 16),

            // Or type your own
            GestureDetector(
              onTap: () => _openChat(context, 'Hello, I need financial advice'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2E7D32), width: 1.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.edit_outlined,
                        color: Color(0xFF2E7D32), size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Ask your own question...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                    Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF2E7D32), size: 14),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── AI insight banner ─────────────────────────────────────────
// Generates one Gemini insight from this month's spending when the AI tab
// opens. Collapses silently if AI is disabled (no API key) or there's no data.
class _AiInsightBanner extends ConsumerStatefulWidget {
  const _AiInsightBanner();

  @override
  ConsumerState<_AiInsightBanner> createState() => _AiInsightBannerState();
}

class _AiInsightBannerState extends ConsumerState<_AiInsightBanner> {
  String? _insight;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final gemini = ref.read(geminiServiceProvider);
    final txs =
        ref.read(allTransactionsProvider).valueOrNull ?? const <Transaction>[];
    if (!gemini.isEnabled || txs.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final now = DateTime.now();
    double income = 0, expense = 0;
    final byCategory = <String, double>{};
    for (final t in txs) {
      if (t.date.year != now.year || t.date.month != now.month) continue;
      if (t.type == 'income') {
        income += t.amount;
      } else if (t.type == 'expense') {
        expense += t.amount;
        byCategory.update(t.categoryName, (v) => v + t.amount,
            ifAbsent: () => t.amount);
      }
    }

    final text = await gemini.getFinancialInsight(
      categoryTotals: byCategory,
      totalExpense: expense,
      totalIncome: income,
      period: 'this month',
    );
    if (mounted) {
      setState(() {
        _insight = text;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show (AI off / no data / empty reply) → take no space.
    if (!_loading && (_insight == null || _insight!.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome,
              color: FinellaColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: _loading
                ? Row(
                    children: const [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF2E7D32)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Analyzing your spending...',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Insight for this month',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _insight!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111827),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _SuggestionCard({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Color(0xFF2E7D32), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFD1D5DB), size: 20),
          ],
        ),
      ),
    );
  }
}
