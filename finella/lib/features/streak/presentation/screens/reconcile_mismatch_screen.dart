import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../../models/reconcile_result.dart';
import 'reconcile_screen.dart' show formatRupee;

const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFEF4444);
const _kBg = Color(0xFFF7FAF4);

class ReconcileMismatchScreen extends StatelessWidget {
  final ReconcileResult result;
  const ReconcileMismatchScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF111827), size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Balance Mismatch',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2E7D32))),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7), shape: BoxShape.circle),
              child: const Center(
                child: Text('⚠️', style: TextStyle(fontSize: 44)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text("Something doesn't add up!",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827))),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Your actual balance is off from what we expected.\n'
              'Find the missing or extra transaction to fix it.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 24),

          // Balance comparison
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEFF1F0)),
            ),
            child: Column(
              children: [
                _row('Expected Balance', formatRupee(r.expected),
                    color: const Color(0xFF6B7280)),
                const SizedBox(height: 12),
                _row('Actual Balance', formatRupee(r.actual),
                    color: const Color(0xFF111827)),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: Color(0xFFF3F4F6)),
                ),
                _row('Difference', formatRupee(r.difference),
                    color: _kRed, bold: true),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('What would you like to do?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827))),
          const SizedBox(height: 12),

          _action(
            icon: Icons.receipt_long_rounded,
            label: 'Review Transactions',
            onTap: () => context.go(RouteNames.activity),
            primary: true,
          ),
          const SizedBox(height: 10),
          _action(
            icon: Icons.add_rounded,
            label: 'Add Missing Transaction',
            onTap: () => context.push(RouteNames.newTransaction),
          ),
          const SizedBox(height: 10),
          _action(
            icon: Icons.schedule_rounded,
            label: 'Reconcile Later',
            onTap: () => context.go(RouteNames.home),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {required Color color, bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF374151))),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: primary
          ? ElevatedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 20),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kGreen,
                side: const BorderSide(color: _kGreen, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
    );
  }
}
