import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodel/auth_view_model.dart';
import 'widgets/auth_widgets.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showError(String? error) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error), backgroundColor: const Color(0xFFEF4444)),
    );
  }

  Future<void> _signUp() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    // All fields are mandatory.
    if (firstName.isEmpty) {
      _showError('Enter your first name');
      return;
    }
    if (lastName.isEmpty) {
      _showError('Enter your last name');
      return;
    }
    if (phone.isEmpty) {
      _showError('Enter your phone number');
      return;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 7) {
      _showError('Enter a valid phone number');
      return;
    }
    if (email.isEmpty || pass.isEmpty) {
      _showError('Enter your email and password');
      return;
    }
    if (pass.length < 6) {
      _showError('Password should be at least 6 characters');
      return;
    }
    if (pass != confirm) {
      _showError('Passwords do not match');
      return;
    }
    final ok = await ref.read(authControllerProvider.notifier).signUpEmail(
          email: email,
          password: pass,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        );
    if (!ok) {
      _showError(ref.read(authControllerProvider).error);
      return;
    }
    if (!mounted) return;
    // Account created but not signed in — send the user to Login to sign in.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Account created! Please sign in.'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () {
            controller.clearError();
            context.pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create account',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Start tracking your money with FinStreak',
                style: TextStyle(fontSize: 15, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 28),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AuthField(
                      controller: _firstNameCtrl,
                      label: 'First name',
                      hint: 'Priya',
                      keyboardType: TextInputType.name,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AuthField(
                      controller: _lastNameCtrl,
                      label: 'Last name',
                      hint: 'Sharma',
                      keyboardType: TextInputType.name,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AuthField(
                controller: _phoneCtrl,
                label: 'Phone number',
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
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
                hint: 'At least 6 characters',
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
              const SizedBox(height: 16),
              AuthField(
                controller: _confirmCtrl,
                label: 'Confirm password',
                hint: 'Re-enter password',
                obscure: _obscure,
              ),
              const SizedBox(height: 24),

              AuthPrimaryButton(
                label: 'Create account',
                isLoading: ui.isLoading,
                onPressed: _signUp,
              ),
              const SizedBox(height: 16),

              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(color: Color(0xFF6B7280))),
                    GestureDetector(
                      onTap: ui.isLoading
                          ? null
                          : () {
                              controller.clearError();
                              context.pop();
                            },
                      child: const Text(
                        'Sign in',
                        style: TextStyle(
                          color: kPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
