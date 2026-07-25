import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_providers.dart';
import '../../features/goals/presentation/widgets/milestone_popup.dart';

// ── Public entry point ────────────────────────────────────────
void showGoalDetail({
  required BuildContext context,
  required WidgetRef ref,
  required Goal goal,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => GoalDetailSheet(
      goal: goal,
      onEdit: () {
        Navigator.pop(ctx);
        _showEditGoalSheet(context, ref, goal);
      },
      onDelete: () async {
        Navigator.pop(ctx);
        await _confirmDelete(context, ref, goal);
      },
    ),
  );
}

// ── Edit sheet ────────────────────────────────────────────────
void _showEditGoalSheet(BuildContext context, WidgetRef ref, Goal goal) {
  final nameCtrl = TextEditingController(text: goal.name);
  final targetCtrl =
      TextEditingController(text: goal.targetAmount.toInt().toString());
  final savedCtrl =
      TextEditingController(text: goal.savedAmount.toInt().toString());

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          const Text(
            'Edit Goal',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 20),

          _GoalField(
              controller: nameCtrl,
              label: 'Goal Name',
              hint: goal.name),
          const SizedBox(height: 12),
          _GoalField(
              controller: targetCtrl,
              label: 'Target Amount (₹)',
              hint: '0',
              numeric: true),
          const SizedBox(height: 12),
          _GoalField(
              controller: savedCtrl,
              label: 'Already Saved (₹)',
              hint: '0',
              numeric: true),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final target =
                    double.tryParse(targetCtrl.text) ?? 0;
                final saved =
                    double.tryParse(savedCtrl.text) ?? 0;
                if (name.isEmpty || target <= 0) return;

                // Capture before update for milestone diff
                final oldSaved = goal.savedAmount;

                await ref.read(goalDaoProvider).updateGoal(
                      goal.copyWith(
                        name: name,
                        targetAmount: target,
                        savedAmount: saved,
                      ),
                    );
                if (ctx.mounted) Navigator.of(ctx).pop();

                // Check milestone using outer context
                if (context.mounted) {
                  checkAndShowMilestone(
                    context: context,
                    goalName: name,
                    oldSaved: oldSaved,
                    newSaved: saved,
                    targetAmount: target,
                  );
                }
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Confirm-delete dialog ─────────────────────────────────────
Future<void> _confirmDelete(
  BuildContext context,
  WidgetRef ref,
  Goal goal,
) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Delete Goal?',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'This will permanently delete "${goal.name}".',
        style:
            const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(
            'Cancel',
            style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(
            'Delete',
            style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  if (confirm == true) {
    await ref.read(goalDaoProvider).deleteGoal(goal.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Goal deleted'),
          backgroundColor: Color(0xFFEF4444),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════
// GoalDetailSheet
// ══════════════════════════════════════════════════════════════
class GoalDetailSheet extends StatelessWidget {
  final Goal goal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const GoalDetailSheet({
    super.key,
    required this.goal,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ((goal.savedAmount / goal.targetAmount) * 100)
        .clamp(0.0, 100.0);
    final remaining =
        (goal.targetAmount - goal.savedAmount).clamp(0.0, double.infinity);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header row ────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF2E7D32),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Goal Details',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 60), // balance Close button
              ],
            ),
          ),

          // ── Main detail card ──────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFE5E7EB), width: 1),
              ),
              child: Column(
                children: [
                  // Goal icon + name + percentage
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(14, 14, 14, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6FAF2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            size: 20,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE5E7EB),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(
                                Color(0xFF2E7D32)),
                      ),
                    ),
                  ),

                  const Divider(height: 1, color: Color(0xFFE5E7EB)),

                  _GoalDetailRow(
                    label: 'Saved',
                    value: _fmt(goal.savedAmount),
                    valueColor: const Color(0xFF22C55E),
                  ),

                  const Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFE5E7EB)),

                  _GoalDetailRow(
                    label: 'Target',
                    value: _fmt(goal.targetAmount),
                  ),

                  const Divider(
                      height: 1,
                      indent: 14,
                      endIndent: 14,
                      color: Color(0xFFE5E7EB)),

                  _GoalDetailRow(
                    label: 'Remaining',
                    value: _fmt(remaining),
                    valueColor: remaining > 0
                        ? const Color(0xFF6B7280)
                        : const Color(0xFF22C55E),
                  ),

                  if (goal.targetDate != null) ...[
                    const Divider(
                        height: 1,
                        indent: 14,
                        endIndent: 14,
                        color: Color(0xFFE5E7EB)),
                    _GoalDetailRow(
                      label: 'Target Date',
                      value: _formatDate(goal.targetDate!),
                    ),
                  ],

                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Edit button ───────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Edit Goal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Delete button ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Delete Goal',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  String _fmt(double v) {
    final n = v.toInt();
    final s = n.toString();
    if (s.length <= 3) return '₹$s';
    if (s.length <= 5) {
      return '₹${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}';
    }
    return '₹${s.substring(0, s.length - 5)},'
        '${s.substring(s.length - 5, s.length - 3)},'
        '${s.substring(s.length - 3)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// ── Label / value row ─────────────────────────────────────────
class _GoalDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _GoalDetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF9CA3AF),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable text field ───────────────────────────────────────
class _GoalField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool numeric;

  const _GoalField({
    required this.controller,
    required this.label,
    required this.hint,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType:
              numeric ? TextInputType.number : TextInputType.text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFD1D5DB)),
            filled: true,
            fillColor: const Color(0xFFF7FAF4),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                  color: Color(0xFF2E7D32), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
