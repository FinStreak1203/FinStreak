import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingWelcomeScreen extends StatelessWidget {
  const OnboardingWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Finella logo ─────────────────────────────
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Center(
                  child: Text(
                    'F',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── App name ─────────────────────────────────
            const Text(
              'Finella',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),

            // ── Tagline ──────────────────────────────────
            const Text(
              'Your money. Your clarity. Your future.',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w400,
              ),
            ),

            const Spacer(flex: 2),

            // ── Feature cards ────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: const [
                  _FeatureCard(
                    icon: Icons.shield_outlined,
                    title: 'Privacy-first',
                    subtitle:
                        'No accounts, no banks. Data stays on your device.',
                  ),
                  SizedBox(height: 12),
                  _FeatureCard(
                    icon: Icons.wifi_off_rounded,
                    title: 'Works offline',
                    subtitle: 'Track expenses anywhere, anytime.',
                  ),
                  SizedBox(height: 12),
                  _FeatureCard(
                    icon: Icons.lock_outline_rounded,
                    title: 'Locked with a PIN',
                    subtitle: 'Only you can see your numbers.',
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // ── Get started button ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => context.go('/currency'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Get started',
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

// ── Feature card ──────────────────────────────────────────────
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF374151), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF9CA3AF),
                    height: 1.4,
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
