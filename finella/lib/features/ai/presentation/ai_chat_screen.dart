import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/services/gemini_service.dart';

// ── Model ─────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;
  ChatMessage({required this.text, required this.isUser, required this.time});
}

// ── Screen ────────────────────────────────────────────────────
class AiChatScreen extends ConsumerStatefulWidget {
  final String initialQuestion;
  const AiChatScreen({super.key, required this.initialQuestion});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;
  bool _showChips = false;

  static const _chips = [
    'Can I increase SIP?',
    'Am I overspending?',
    'How much can I invest?',
    'Show my goal progress',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendMessage(widget.initialQuestion);
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Logic ──────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    _inputCtrl.clear();
    setState(() {
      _messages
          .add(ChatMessage(text: text.trim(), isUser: true, time: DateTime.now()));
      _isTyping = true;
      _showChips = false;
    });
    _scrollToBottom();

    final gemini = ref.read(geminiServiceProvider);
    String reply;
    if (gemini.isEnabled) {
      reply = await gemini.chat(
        userMessage: text.trim(),
        transactionContext: _buildTransactionContext(),
      );
    } else {
      // No API key configured — keep the canned demo response so the chat
      // still feels alive in development.
      await Future.delayed(const Duration(milliseconds: 1200));
      reply = _getResponse(text);
    }
    if (!mounted) return;

    setState(() {
      _isTyping = false;
      _showChips = true;
      _messages
          .add(ChatMessage(text: reply, isUser: false, time: DateTime.now()));
    });
    _scrollToBottom();
  }

  /// Builds a compact, real summary of the signed-in user's money for this
  /// month, passed to Gemini as grounding context for every chat reply.
  String _buildTransactionContext() {
    final txs =
        ref.read(allTransactionsProvider).valueOrNull ?? const <Transaction>[];
    if (txs.isEmpty) return 'The user has no transactions recorded yet.';

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
    final cats = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final catLines = cats
        .take(8)
        .map((e) => '- ${e.key}: ₹${e.value.toStringAsFixed(0)}')
        .join('\n');

    return 'This month (${_monthNames[now.month - 1]} ${now.year}):\n'
        'Total income: ₹${income.toStringAsFixed(0)}\n'
        'Total expense: ₹${expense.toStringAsFixed(0)}\n'
        'Spending by category:\n${catLines.isEmpty ? '- none yet' : catLines}\n'
        'Total transactions on record: ${txs.length}';
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _getResponse(String q) {
    final lower = q.toLowerCase();
    if (lower.contains('save') || lower.contains('saving')) {
      return 'Based on your spending patterns this month:\n\n'
          '1. Reduce food delivery (₹4,200 spent)\n'
          '   · Cook 3x/week → save ₹2,500\n\n'
          '2. Cancel unused Hotstar subscription\n'
          '   · Save ₹299/month\n\n'
          '3. Switch to annual Spotify plan\n'
          '   · Save ₹120/month\n\n'
          'Total potential savings: ₹2,919/month 🎯';
    }
    if (lower.contains('emi') || lower.contains('afford')) {
      return 'Based on your income of ₹55,000 and current expenses of ₹9,770:\n\n'
          'Safe EMI limit (40% rule): ₹22,000/month max\n\n'
          'You can comfortably afford an EMI up to ₹12,000/month. '
          'Going above that increases financial stress risk.';
    }
    if (lower.contains('invest') || lower.contains('sip')) {
      return 'After monthly expenses of ₹9,770, you have ₹45,230 free.\n\n'
          'Recommended split:\n'
          '• SIP: ₹5,000/month\n'
          '• Emergency buffer: ₹3,000/month\n'
          '• Goals top-up: ₹2,000/month\n\n'
          'Start small and increase 10% every year. Consistency beats timing! 📈';
    }
    if (lower.contains('overspend') || lower.contains('spending')) {
      return 'Your May spending summary:\n\n'
          '• Food: ₹3,420 (35%) — HIGH ⚠️\n'
          '• Shopping: ₹2,300 (23%)\n'
          '• Travel: ₹1,760 (18%)\n'
          '• Others: ₹2,290 (24%)\n\n'
          'Food is 40% above your weekly average. '
          'Try cooking at home this week to bring it down!';
    }
    if (lower.contains('goal') || lower.contains('progress')) {
      return 'Your current goal progress:\n\n'
          '• iPhone 16 Pro: 32%\n'
          '  ₹42,000 / ₹1,29,900\n\n'
          '• Emergency Fund: 40%\n'
          '  ₹80,000 / ₹2,00,000\n\n'
          'At this rate, Emergency Fund hits Silver milestone next month! 🏅';
    }
    return 'Great question! Based on your financial data, you\'re doing well overall. '
        'What specific area would you like advice on?\n\n'
        '• Spending habits\n'
        '• Investment options\n'
        '• Goal planning\n'
        '• EMI affordability';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF2E7D32),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FinStreak AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  'Financial Coach',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 14),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFDE68A), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium,
                    size: 13, color: Color(0xFFD4AF37)),
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
        ],
      ),
      body: Column(
        children: [
          // ── Chat list ────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (_isTyping && i == _messages.length) {
                  return _buildTypingBubble();
                }
                final msg = _messages[i];
                return msg.isUser
                    ? _buildUserBubble(msg)
                    : _buildAiBubble(msg);
              },
            ),
          ),

          // ── Chips ────────────────────────────────────────
          if (_showChips) _buildSuggestedChips(),

          // ── Input bar ────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── Bubbles ────────────────────────────────────────────────

  Widget _buildUserBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6, left: 64),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: Color(0xFF2E7D32),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _formatTime(msg.time),
              style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiBubble(ChatMessage msg) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
                color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 6, right: 64),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF374151),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.time),
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF9CA3AF)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
                color: Color(0xFF2E7D32), shape: BoxShape.circle),
            child: const Icon(Icons.psychology_rounded,
                color: Colors.white, size: 15),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PulsingDot(delay: Duration.zero),
                SizedBox(width: 4),
                _PulsingDot(delay: Duration(milliseconds: 200)),
                SizedBox(width: 4),
                _PulsingDot(delay: Duration(milliseconds: 400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Chips + input ──────────────────────────────────────────

  Widget _buildSuggestedChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _chips.length,
        itemBuilder: (ctx, i) => GestureDetector(
          onTap: () => _sendMessage(_chips[i]),
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _chips[i],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 8, 14, MediaQuery.of(context).padding.bottom + 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6), width: 1)),
      ),
      child: Row(
        children: [
          // Mic
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6), shape: BoxShape.circle),
            child: const Icon(Icons.mic_outlined,
                color: Color(0xFF6B7280), size: 20),
          ),
          const SizedBox(width: 10),

          // Text field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF4),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: TextField(
                controller: _inputCtrl,
                onSubmitted: _sendMessage,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF111827)),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                      fontSize: 14, color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Send
          GestureDetector(
            onTap: () => _sendMessage(_inputCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: Color(0xFF2E7D32), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dot (typing indicator) ───────────────────────────
class _PulsingDot extends StatefulWidget {
  final Duration delay;
  const _PulsingDot({required this.delay});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0.25, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
            color: Color(0xFF2E7D32), shape: BoxShape.circle),
      ),
    );
  }
}
