import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/subscription_provider.dart';

class OnboardingCurrencyScreen extends ConsumerStatefulWidget {
  const OnboardingCurrencyScreen({super.key});

  @override
  ConsumerState<OnboardingCurrencyScreen> createState() =>
      _OnboardingCurrencyScreenState();
}

class _OnboardingCurrencyScreenState
    extends ConsumerState<OnboardingCurrencyScreen> {
  String _selected = 'INR';

  static const _currencies = [
    {'code': 'USD', 'name': 'US Dollar', 'symbol': '\$'},
    {'code': 'EUR', 'name': 'Euro', 'symbol': '€'},
    {'code': 'GBP', 'name': 'British Pound', 'symbol': '£'},
    {'code': 'INR', 'name': 'Indian Rupee', 'symbol': '₹'},
    {'code': 'JPY', 'name': 'Japanese Yen', 'symbol': '¥'},
    {'code': 'CAD', 'name': 'Canadian Dollar', 'symbol': 'C\$'},
    {'code': 'AUD', 'name': 'Australian Dollar', 'symbol': 'A\$'},
    {'code': 'SGD', 'name': 'Singapore Dollar', 'symbol': 'S\$'},
    {'code': 'AED', 'name': 'UAE Dirham', 'symbol': 'د.إ'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Choose your currency',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'You can change this later in Settings.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),

            // ── Currency list ─────────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _currencies.length,
                itemBuilder: (ctx, i) {
                  final c = _currencies[i];
                  final isSelected = _selected == c['code'];

                  return GestureDetector(
                    onTap: () =>
                        setState(() => _selected = c['code']!),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF0FDF4)
                            : Colors.white,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE5E7EB),
                          width: isSelected ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          // Symbol circle
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF2E7D32)
                                  : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                c['symbol']!,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF374151),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Code + name
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c['code']!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                                Text(
                                  c['name']!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF2E7D32),
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Continue button ───────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () async {
                    final prefs =
                        ref.read(sharedPreferencesProvider);
                    await prefs.setString('currency', _selected);
                    if (context.mounted) {
                      context.go('/create-pin');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
