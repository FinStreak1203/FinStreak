import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Reset / change the app PIN from Settings. Two steps in one screen: enter a
/// new 4-digit PIN, then confirm it. On a match the PIN is written to secure
/// storage (key `user_pin`) and the screen pops with a success message.
class ResetPinScreen extends StatefulWidget {
  const ResetPinScreen({super.key});

  @override
  State<ResetPinScreen> createState() => _ResetPinScreenState();
}

class _ResetPinScreenState extends State<ResetPinScreen> {
  static const _storage = FlutterSecureStorage();

  // 'enter' → type the new PIN; 'confirm' → re-type to confirm.
  String _stage = 'enter';
  String _newPin = '';
  String _pin = ''; // digits entered in the current stage
  bool _error = false;
  bool _saving = false;

  void _onKey(String key) {
    if (_saving) return;
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() {
          _pin = _pin.substring(0, _pin.length - 1);
          _error = false;
        });
      }
      return;
    }
    if (_pin.length >= 4) return;
    setState(() {
      _pin += key;
      _error = false;
    });
    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 150), _onComplete);
    }
  }

  Future<void> _onComplete() async {
    if (!mounted) return;
    if (_stage == 'enter') {
      setState(() {
        _newPin = _pin;
        _pin = '';
        _stage = 'confirm';
      });
      return;
    }
    // confirm stage
    if (_pin == _newPin) {
      setState(() => _saving = true);
      try {
        await _storage.write(key: 'user_pin', value: _newPin);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN updated'),
          backgroundColor: Color(0xFF2E7D32),
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = true;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfirm = _stage == 'confirm';
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () {
            // Back from confirm returns to the enter step, not out of the flow.
            if (isConfirm) {
              setState(() {
                _stage = 'enter';
                _pin = '';
                _newPin = '';
                _error = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text('Reset PIN',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              isConfirm ? 'Confirm new PIN' : 'Set a new PIN',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isConfirm
                  ? 'Enter the same PIN again to confirm.'
                  : 'Choose a 4-digit PIN to secure the app.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // 4 dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _pin.length;
                final on = _error
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2E7D32);
                return Container(
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error
                        ? const Color(0xFFEF4444)
                        : filled
                            ? on
                            : const Color(0xFFE5E7EB),
                    border: Border.all(
                      color: _error
                          ? const Color(0xFFEF4444)
                          : filled
                              ? on
                              : const Color(0xFFD1D5DB),
                      width: 1.5,
                    ),
                  ),
                );
              }),
            ),

            if (_error) ...[
              const SizedBox(height: 16),
              const Text(
                "PINs don't match. Try again.",
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],

            const Spacer(flex: 2),

            // Number pad
            for (final row in const [
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
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                    color: Color(0xFFE5E7EB), width: 0.5),
                                right: BorderSide(
                                    color: Color(0xFFE5E7EB), width: 0.5),
                              ),
                            ),
                            child: Center(
                              child: key == '⌫'
                                  ? const Icon(Icons.backspace_outlined,
                                      color: Color(0xFF374151), size: 22)
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
