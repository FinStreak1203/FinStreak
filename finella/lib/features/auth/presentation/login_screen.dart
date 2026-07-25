import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodel/auth_view_model.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _showError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  Future<void> _emailLogin() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      _showError('Enter your email and password');
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier)
        .signInEmail(email, pass);
    if (!ok) _showError(ref.read(authControllerProvider).error);
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email first, then tap "Forgot password".');
      return;
    }
    await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    final err = ref.read(authControllerProvider).error;
    if (err != null) {
      _showError(err);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset link sent to $email'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F0EC),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: kPrimary, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sign in to continue to Finella',
                style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 28),

              AuthField(
                controller: _emailCtrl,
                label: 'Email',
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _passwordCtrl,
                label: 'Password',
                hint: '••••••••',
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: ui.isLoading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              AuthPrimaryButton(
                label: 'Sign in',
                isLoading: ui.isLoading,
                onPressed: _emailLogin,
              ),
              const SizedBox(height: 20),

              Row(
                children: const [
                  Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(color: Color(0xFF9CA3AF))),
                  ),
                  Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                ],
              ),
              const SizedBox(height: 20),

              GoogleButton(
                isLoading: ui.isLoading,
                onPressed: () async {
                  final ok = await controller.signInGoogle();
                  if (!ok) _showError(ref.read(authControllerProvider).error);
                },
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: ui.isLoading
                      ? null
                      : () async {
                          final ok = await controller.signInGuest();
                          if (!ok) {
                            _showError(ref.read(authControllerProvider).error);
                          }
                        },
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: Color(0xFF6B7280))),
                    GestureDetector(
                      onTap: ui.isLoading
                          ? null
                          : () {
                              controller.clearError();
                              context.push('/signup');
                            },
                      child: const Text(
                        'Sign up',
                        style: TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
