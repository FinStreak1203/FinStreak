import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/services/gmail_auth_service.dart';
import '../../../core/services/sms_service.dart';
import '../../auth/viewmodel/auth_view_model.dart';
import 'reset_pin_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
          'You will need to sign in again to access your account.',
          style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(
                    color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out',
                style: TextStyle(
                    color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // Auth gate rebuilds to the login screen once signed out.
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final isPremium = ref.watch(isPremiumProvider);
    final gmailConnected =
        ref.watch(gmailConnectedProvider).valueOrNull ?? false;
    final smsGranted = ref.watch(smsPermissionProvider).valueOrNull ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7FAF4),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2E7D32),
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── SECTION 1: ACCOUNT ────────────────────────
            const _SectionLabel('ACCOUNT'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.person_outline_rounded,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Profile',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD1D5DB), size: 20),
                onTap: () => context.push(RouteNames.profile),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.workspace_premium_rounded,
                iconBg: const Color(0xFFFEF9C3),
                iconColor: const Color(0xFFD4AF37),
                label: isPremium
                    ? 'Subscription: Premium'
                    : 'Subscription: Free',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: isPremium
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPremium ? 'Active' : 'Upgrade',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isPremium
                              ? Colors.white
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD1D5DB), size: 20),
                  ],
                ),
                onTap: isPremium
                    ? null
                    : () => context.push(RouteNames.premium),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.account_balance_wallet_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Account',
                trailing: const Icon(Icons.chevron_right,
                    color: Color(0xFFD1D5DB), size: 20),
                onTap: () => context.push(RouteNames.accounts),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.pie_chart_outline,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Budget',
                trailing: const Icon(Icons.chevron_right,
                    color: Color(0xFFD1D5DB), size: 20),
                onTap: () => context.push(RouteNames.budgets),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.logout_rounded,
                iconBg: const Color(0xFFFEE2E2),
                iconColor: const Color(0xFFEF4444),
                label: 'Sign out',
                trailing: const SizedBox.shrink(),
                onTap: () => _confirmSignOut(context, ref),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 2: INPUT METHOD ───────────────────
            const _SectionLabel('INPUT METHOD'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.edit_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Manual Entry',
                trailing: _GreenSwitch(
                  value: settings.manualEntryEnabled,
                  onChanged: notifier.toggleManualEntry,
                ),
              ),
              const _Divider(),
              if (Platform.isAndroid) ...[
                _SettingsRow(
                  icon: Icons.sms_outlined,
                  iconBg: const Color(0xFFEAF5E4),
                  iconColor: const Color(0xFF2E7D32),
                  label: 'SMS Parsing',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: smsGranted
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          smsGranted ? 'Active' : 'Enable',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: smsGranted
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFFD1D5DB), size: 20),
                    ],
                  ),
                  onTap: () async {
                    await context.push(RouteNames.smsImport);
                    ref.invalidate(smsPermissionProvider); // refresh badge
                  },
                ),
                const _Divider(),
              ],
              _SettingsRow(
                icon: Icons.account_balance_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Bank Sync',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: settings.bankSyncConnected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        settings.bankSyncConnected
                            ? 'Connected'
                            : 'Connect',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: settings.bankSyncConnected
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD1D5DB), size: 20),
                  ],
                ),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.mark_email_read_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Email Parsing',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: gmailConnected
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        gmailConnected ? 'Active' : 'Connect',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: gmailConnected
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD1D5DB), size: 20),
                  ],
                ),
                onTap: () => context.push(RouteNames.emailImport),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.picture_as_pdf_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'PDF Statement',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD1D5DB), size: 20),
                onTap: () => context.push(RouteNames.pdfImport),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 3: AI PREFERENCES ─────────────────
            const _SectionLabel('AI PREFERENCES'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.chat_rounded,
                iconBg: const Color(0xFFDCFCE7),
                iconColor: const Color(0xFF22C55E),
                label: 'WhatsApp Notifications',
                sublabel: isPremium ? null : 'Premium only',
                trailing: isPremium
                    ? _GreenSwitch(
                        value: settings.whatsappNotifs,
                        onChanged: notifier.toggleWhatsapp,
                      )
                    : const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFFD1D5DB), size: 18),
                onTap: isPremium
                    ? null
                    : () => context.push(RouteNames.premium),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.notifications_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Push Notifications',
                trailing: _GreenSwitch(
                  value: settings.pushNotifs,
                  onChanged: notifier.togglePushNotifs,
                ),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.access_time_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'AI Alert Frequency',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.alertFrequency,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFFD1D5DB), size: 20),
                  ],
                ),
                onTap: () =>
                    _showFrequencyPicker(context, settings, notifier),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 4: SECURITY ───────────────────────
            const _SectionLabel('SECURITY'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.lock_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Reset PIN',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD1D5DB), size: 20),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResetPinScreen()),
                ),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.fingerprint_rounded,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Biometric Unlock',
                trailing: settings.biometricEnabled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Enabled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : _GreenSwitch(
                        value: false,
                        onChanged: notifier.toggleBiometric,
                      ),
                onTap: settings.biometricEnabled
                    ? () => notifier.toggleBiometric(false)
                    : null,
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 5: APP ────────────────────────────
            const _SectionLabel('APP'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.language_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Base Currency: INR (₹)',
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Color(0xFFD1D5DB), size: 20),
              ),
              const _Divider(),
              _SettingsRow(
                icon: Icons.dark_mode_outlined,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Dark Mode',
                trailing: _GreenSwitch(
                  value: settings.darkMode,
                  onChanged: notifier.toggleDarkMode,
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 6: ABOUT ──────────────────────────
            const _SectionLabel('ABOUT'),
            _SettingsCard(children: [
              _SettingsRow(
                icon: Icons.info_outline_rounded,
                iconBg: const Color(0xFFEAF5E4),
                iconColor: const Color(0xFF2E7D32),
                label: 'Finella',
                sublabel: 'Version 1.0',
                trailing: const SizedBox.shrink(),
              ),
            ]),

            const SizedBox(height: 20),

            // ── SECTION 7: DEVELOPER (test toggle) ───────
            const _SectionLabel('DEVELOPER'),
            _DevPlanToggle(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showFrequencyPicker(
    BuildContext context,
    SettingsState settings,
    SettingsNotifier notifier,
  ) {
    const options = ['Real-time', 'Daily', 'Weekly'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'AI Alert Frequency',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),
            for (final opt in options)
              GestureDetector(
                onTap: () {
                  notifier.setAlertFrequency(opt);
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 14, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: settings.alertFrequency == opt
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFF7FAF4),
                    border: Border.all(
                      color: settings.alertFrequency == opt
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        opt,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: settings.alertFrequency == opt
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF374151),
                        ),
                      ),
                      const Spacer(),
                      if (settings.alertFrequency == opt)
                        const Icon(Icons.check_rounded,
                            color: Color(0xFF2E7D32), size: 18),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Green Switch helper ───────────────────────────────────────
class _GreenSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _GreenSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: const Color(0xFF2E7D32),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE5E7EB),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}

// ── Section label ─────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.8,
          ),
        ),
      );
}

// ── White card container ──────────────────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD1D5DB), width: 1.2),
        ),
        child: Column(children: children),
      );
}

// ── Individual settings row ───────────────────────────────────
class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String? sublabel;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    this.sublabel,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (sublabel != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        sublabel!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      );
}

// ── Thin inset divider ────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        thickness: 0.8,
        color: Color(0xFFE5E7EB),
        indent: 62,
        endIndent: 0,
      );
}

// ── Developer plan toggle ─────────────────────────────────────
class _DevPlanToggle extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumProvider);
    final notifier  = ref.read(subscriptionProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Current status badge
          Row(
            children: [
              const Text(
                'Current plan:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isPremium
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFF6B7280),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isPremium ? '✦ Premium' : 'Free',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Toggle buttons
          Row(
            children: [
              Expanded(
                child: _DevButton(
                  label: 'Free',
                  icon: Icons.person_outline_rounded,
                  active: !isPremium,
                  activeColor: const Color(0xFF6B7280),
                  onTap: () => notifier.downgradeToFree(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DevButton(
                  label: 'Premium',
                  icon: Icons.workspace_premium_rounded,
                  active: isPremium,
                  activeColor: const Color(0xFF2E7D32),
                  onTap: () => notifier.upgradeToPremium(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DevButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final VoidCallback onTap;

  const _DevButton({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? activeColor : const Color(0xFFF7FAF4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? activeColor : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Colors.white : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : const Color(0xFF9CA3AF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
