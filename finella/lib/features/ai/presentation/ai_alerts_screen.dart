import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/subscription_provider.dart';

// ── Model ──────────────────────────────────────────────────────
enum AlertType {
  unusualSpending,
  weeklySummary,
  savingSuggestion,
  budgetWarning,
  goalUpdate,
}

class AlertItem {
  final String title;
  final String body;
  final String timeAgo;
  final AlertType type;
  final Color borderColor;
  final Color iconBg;
  final Color iconColor;
  final IconData icon;

  const AlertItem({
    required this.title,
    required this.body,
    required this.timeAgo,
    required this.type,
    required this.borderColor,
    required this.iconBg,
    required this.iconColor,
    required this.icon,
  });
}

// ── Screen ─────────────────────────────────────────────────────
class AiAlertsScreen extends ConsumerStatefulWidget {
  const AiAlertsScreen({super.key});

  @override
  ConsumerState<AiAlertsScreen> createState() => _AiAlertsScreenState();
}

class _AiAlertsScreenState extends ConsumerState<AiAlertsScreen> {
  bool _whatsappEnabled = true;
  bool _dailyDigest     = true;
  bool _realtimeAlerts  = true;
  bool _weeklySummary   = true;

  final List<AlertItem> _alerts = [
    const AlertItem(
      title: 'Unusual Spending',
      body: 'You spent ₹4,500 on food delivery today, 3x your daily average',
      timeAgo: '2 hours ago',
      type: AlertType.unusualSpending,
      borderColor: Color(0xFFEF4444),
      iconBg: Color(0xFFFFF1F2),
      iconColor: Color(0xFFEF4444),
      icon: Icons.warning_amber_rounded,
    ),
    const AlertItem(
      title: 'Weekly Summary',
      body: 'You saved ₹3,200 this week, 15% better than last week!',
      timeAgo: '1 day ago',
      type: AlertType.weeklySummary,
      borderColor: Color(0xFF22C55E),
      iconBg: Color(0xFFF0FDF4),
      iconColor: Color(0xFF22C55E),
      icon: Icons.trending_up_rounded,
    ),
    const AlertItem(
      title: 'Saving Suggestion',
      body: 'Switch electricity bill to autopay and save ₹200/month',
      timeAgo: '2 days ago',
      type: AlertType.savingSuggestion,
      borderColor: Color(0xFFD4AF37),
      iconBg: Color(0xFFFEFCE8),
      iconColor: Color(0xFFD4AF37),
      icon: Icons.lightbulb_outline_rounded,
    ),
    const AlertItem(
      title: 'Budget Warning',
      body: 'Shopping budget 85% used, 10 days remaining',
      timeAgo: '3 days ago',
      type: AlertType.budgetWarning,
      borderColor: Color(0xFFF97316),
      iconBg: Color(0xFFFFF7ED),
      iconColor: Color(0xFFF97316),
      icon: Icons.bar_chart_rounded,
    ),
    const AlertItem(
      title: 'Goal Update',
      body: 'Emergency Fund reached Silver milestone (20%)!',
      timeAgo: '4 days ago',
      type: AlertType.goalUpdate,
      borderColor: Color(0xFFC0C0C0),
      iconBg: Color(0xFFF5F5F5),
      iconColor: Color(0xFFC0C0C0),
      icon: Icons.emoji_events_outlined,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _whatsappEnabled = prefs.getBool('alert_whatsapp')        ?? true;
    _dailyDigest     = prefs.getBool('alert_daily_digest')    ?? true;
    _realtimeAlerts  = prefs.getBool('alert_realtime')        ?? true;
    _weeklySummary   = prefs.getBool('alert_weekly_summary')  ?? true;
  }

  void _saveToggle(String key, bool value) =>
      ref.read(sharedPreferencesProvider).setBool(key, value);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF4),

      // ── AppBar ───────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF111827),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'AI Alerts',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32),
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFF2E7D32),
              size: 22,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => setState(() => _alerts.clear()),
            child: const Text(
              'Clear all',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),

      // ── Body ─────────────────────────────────────────────
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── 1. WhatsApp Card ─────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'WhatsApp Alerts',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF065F46),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Get alerts on WhatsApp',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _whatsappEnabled,
                    onChanged: (v) {
                      setState(() => _whatsappEnabled = v);
                      _saveToggle('alert_whatsapp', v);
                    },
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFF2E7D32),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFE5E7EB),
                    trackOutlineColor:
                        WidgetStateProperty.all(Colors.transparent),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── 2. Recent Alerts ─────────────────────────
            const Text(
              'RECENT ALERTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            if (_alerts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: const [
                      Icon(Icons.notifications_off_outlined,
                          size: 48, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text(
                        'No alerts',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._alerts.map(_buildAlertCard),

            const SizedBox(height: 20),

            // ── 3. Settings ──────────────────────────────
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                children: [
                  _SettingsToggleRow(
                    label: 'Daily Digest',
                    subtitle: 'Summary of your day every evening',
                    value: _dailyDigest,
                    onChanged: (v) {
                      setState(() => _dailyDigest = v);
                      _saveToggle('alert_daily_digest', v);
                    },
                  ),
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF3F4F6)),
                  _SettingsToggleRow(
                    label: 'Real-time Alerts',
                    subtitle: 'Instant notifications for unusual activity',
                    value: _realtimeAlerts,
                    onChanged: (v) {
                      setState(() => _realtimeAlerts = v);
                      _saveToggle('alert_realtime', v);
                    },
                  ),
                  const Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Color(0xFFF3F4F6)),
                  _SettingsToggleRow(
                    label: 'Weekly Summary',
                    subtitle: 'Your week in finance every Sunday',
                    value: _weeklySummary,
                    onChanged: (v) {
                      setState(() => _weeklySummary = v);
                      _saveToggle('alert_weekly_summary', v);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── Alert card ──────────────────────────────────────────
  Widget _buildAlertCard(AlertItem alert) {
    // Use clipBehavior + uniform border + inner coloured accent bar
    // to avoid the "borderRadius with non-uniform border colors" error.
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border.all(color: const Color(0xFFF3F4F6), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coloured left accent bar
          Container(width: 4, color: alert.borderColor),

          // Card content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: alert.iconBg,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child:
                        Icon(alert.icon, color: alert.iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          alert.body,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          alert.timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings toggle row ────────────────────────────────────────
class _SettingsToggleRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF2E7D32),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFE5E7EB),
            trackOutlineColor:
                WidgetStateProperty.all(Colors.transparent),
          ),
        ],
      ),
    );
  }
}
