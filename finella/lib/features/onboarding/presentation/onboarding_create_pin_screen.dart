import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingCreatePinScreen extends StatefulWidget {
  const OnboardingCreatePinScreen({super.key});

  @override
  State<OnboardingCreatePinScreen> createState() =>
      _OnboardingCreatePinScreenState();
}

class _OnboardingCreatePinScreenState
    extends State<OnboardingCreatePinScreen> {
  String _pin = '';

  void _onKey(String key) {
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
    } else if (_pin.length < 4) {
      setState(() => _pin += key);
      if (_pin.length == 4) {
        Future.delayed(
          const Duration(milliseconds: 200),
          () {
            if (mounted) {
              context.go('/confirm-pin', extra: _pin);
            }
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // ── Title ────────────────────────────────────
            const Text(
              'Create a 4-digit PIN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You\'ll use this PIN to unlock Finella.',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // ── 4 dot indicators ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFE5E7EB),
                    border: Border.all(
                      color: filled
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),

            const Spacer(flex: 2),

            // ── Number pad ───────────────────────────────
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫'],
            ])
              Row(
                children: row
                    .map(
                      (key) => Expanded(
                        child: InkWell(
                          onTap: key.isEmpty ? null : () => _onKey(key),
                          child: Container(
                            height: 80,
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                                right: BorderSide(
                                  color: const Color(0xFFE5E7EB),
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: Center(
                              child: key == '⌫'
                                  ? const Icon(
                                      Icons.backspace_outlined,
                                      color: Color(0xFF374151),
                                      size: 22,
                                    )
                                  : key.isEmpty
                                      ? null
                                      : Text(
                                          key,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w400,
                                            color: Color(0xFF111827),
                                          ),
                                        ),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
