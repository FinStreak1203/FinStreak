import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/onboarding_provider.dart';
import '../../../core/providers/subscription_provider.dart';

class OnboardingAddAccountScreen extends ConsumerStatefulWidget {
  const OnboardingAddAccountScreen({super.key});

  @override
  ConsumerState<OnboardingAddAccountScreen> createState() =>
      _OnboardingAddAccountScreenState();
}

class _OnboardingAddAccountScreenState
    extends ConsumerState<OnboardingAddAccountScreen> {
  String _accountType = 'cash';
  final _nameCtrl = TextEditingController(text: 'My Wallet');
  final _balanceCtrl = TextEditingController(text: '0');
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _startTracking() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final name = _nameCtrl.text.trim().isEmpty
        ? 'My Wallet'
        : _nameCtrl.text.trim();
    final balance = double.tryParse(_balanceCtrl.text) ?? 0.0;

    try {
      // 1. Save account (Firestore-backed)
      await ref.read(accountDaoProvider).insertAccount(
            AccountsCompanion(
              name: Value(name),
              type: Value(_accountType),
              balance: Value(balance),
            ),
          );

      // 2. Mark onboarding complete for THIS user
      final prefs = ref.read(sharedPreferencesProvider);
      final uid = ref.read(currentUidProvider);
      if (uid != null) {
        await prefs.setBool(onboardingKey(uid), true);
      }

      // 3. Invalidate provider → FinellaApp rebuilds → main router loads
      ref.invalidate(onboardingCompleteProvider);
    } catch (e) {
      // Never leave the button stuck spinning — surface the error and let the
      // user retry.
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t start tracking: $e')),
      );
    }
  }

  void _selectType(String type, String defaultName) {
    setState(() {
      _accountType = type;
      _nameCtrl.text = defaultName;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: Column(
          children: [
            // ── Progress bar (4/4 filled) ─────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: List.generate(
                  4,
                  (i) => Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E7D32),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Scrollable body ───────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Title
                    const Text(
                      'Add your first account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Where do you keep your money?',
                      style: TextStyle(
                          fontSize: 14, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 24),

                    // ── Account type selector ─────────────
                    Row(
                      children: [
                        _TypeCard(
                          icon: Icons.wallet_outlined,
                          label: 'Cash',
                          isSelected: _accountType == 'cash',
                          onTap: () =>
                              _selectType('cash', 'My Wallet'),
                        ),
                        const SizedBox(width: 12),
                        _TypeCard(
                          icon: Icons.account_balance_outlined,
                          label: 'Bank',
                          isSelected: _accountType == 'bank',
                          onTap: () =>
                              _selectType('bank', 'My Bank'),
                        ),
                        const SizedBox(width: 12),
                        _TypeCard(
                          icon: Icons.credit_card_outlined,
                          label: 'Credit Card',
                          isSelected: _accountType == 'credit_card',
                          onTap: () =>
                              _selectType('credit_card', 'My Card'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Account name field ────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ACCOUNT NAME',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextField(
                            controller: _nameCtrl,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Opening balance field ─────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'OPENING BALANCE',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                              letterSpacing: 0.8,
                            ),
                          ),
                          TextField(
                            controller: _balanceCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF111827),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(top: 4),
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Leave at 0 if you prefer to set it later',
                            style: TextStyle(
                              fontSize: 12,
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

            // ── Start tracking button ─────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _startTracking,
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
                          'Start tracking',
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

// ── Account type card ─────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF2E7D32)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF374151),
                ),
                textAlign: TextAlign.center,
              ),
              if (isSelected) ...[
                const SizedBox(height: 6),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
