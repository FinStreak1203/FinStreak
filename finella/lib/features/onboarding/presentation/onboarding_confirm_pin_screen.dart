import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class OnboardingConfirmPinScreen extends StatefulWidget {
  final String pin;
  const OnboardingConfirmPinScreen({super.key, required this.pin});

  @override
  State<OnboardingConfirmPinScreen> createState() =>
      _OnboardingConfirmPinScreenState();
}

class _OnboardingConfirmPinScreenState
    extends State<OnboardingConfirmPinScreen> {
  String _confirmPin = '';
  bool _hasError = false;

  static const _storage = FlutterSecureStorage();

  void _onKey(String key) {
    if (key == '⌫') {
      if (_confirmPin.isNotEmpty) {
        setState(() {
          _confirmPin =
              _confirmPin.substring(0, _confirmPin.length - 1);
          _hasError = false;
        });
      }
    } else if (_confirmPin.length < 4) {
      setState(() {
        _confirmPin += key;
        _hasError = false;
      });

      if (_confirmPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () async {
          if (!mounted) return;
          if (_confirmPin == widget.pin) {
            // Save PIN securely
            await _storage.write(
                key: 'user_pin', value: widget.pin);
            if (mounted) context.go('/add-account');
          } else {
            setState(() {
              _hasError = true;
              _confirmPin = '';
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('PINs don\'t match. Try again.'),
                  backgroundColor: Color(0xFFEF4444),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        });
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
              'Confirm your PIN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter the same PIN again to confirm.',
              style: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // ── 4 dot indicators ─────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _confirmPin.length;
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _hasError
                        ? const Color(0xFFEF4444)
                        : filled
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE5E7EB),
                    border: Border.all(
                      color: _hasError
                          ? const Color(0xFFEF4444)
                          : filled
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),

            if (_hasError) ...[
              const SizedBox(height: 16),
              const Text(
                'PINs don\'t match. Try again.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

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
