import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/subscription_provider.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  String _selectedPlan = 'yearly';
  bool _isLoading = false;

  static const _features = [
    'AI Financial Coach',
    'Smart Saving Suggestions',
    'WhatsApp Alerts & Summaries',
    'Anomaly & Duplicate Detection',
    'Spending Psychology Analysis',
    'AI Goal Planning',
    'Predictive Analytics',
    'Priority Support',
  ];

  Future<void> _startTrial() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    ref.read(subscriptionProvider.notifier).upgradeToPremium();
    setState(() => _isLoading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Finella Premium!'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF111827), size: 24),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. LOGO + CROWN ───────────────────────────
            const SizedBox(height: 16),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.workspace_premium,
                      color: Color(0xFFD4AF37), size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Finella',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── 2. HEADLINE ───────────────────────────────
            const Text(
              'Unlock Financial Superpowers',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // ── 3. SUBTITLE ───────────────────────────────
            const Text(
              'Finella Premium',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // ── 4. FEATURE LIST (2 columns) ───────────────
            Container(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 3.5,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                children: _features
                    .map(
                      (feature) => Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: Color(0xFF2E7D32),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── 5. PRICING CARDS ──────────────────────────
            Row(
              children: [
                // Monthly card
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedPlan = 'monthly'),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                          color: _selectedPlan == 'monthly'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE5E7EB),
                          width: _selectedPlan == 'monthly' ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: '₹199',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                TextSpan(
                                  text: '/month',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                // Yearly card (Most Popular)
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedPlan = 'yearly'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: const Color(0xFF2E7D32),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Yearly',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Flexible(
                                    child: RichText(
                                      text: const TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '₹1,999',
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight:
                                                  FontWeight.w700,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          TextSpan(
                                            text: '/yr',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF9CA3AF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCFCE7),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Save 16%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // "Most Popular" floating badge
                        Positioned(
                          top: -12,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2E7D32),
                                borderRadius:
                                    BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Most Popular',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── 6. START FREE TRIAL BUTTON ────────────────
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startTrial,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2)
                    : const Text(
                        'Start 7-Day Free Trial',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 7. TRUST ROW ──────────────────────────────
            const Text(
              'Cancel anytime  ·  50,000+ users  ·  Bank-grade security',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // ── 8. 250-DAY OFFER CARD ─────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    children: [
                      TextSpan(
                        text:
                            'Open app 250 days and get next year ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      TextSpan(
                        text: 'FREE! ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      TextSpan(
                        text: '🔥',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
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
