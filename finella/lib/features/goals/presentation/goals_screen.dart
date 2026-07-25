import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/goal_dao.dart';
import '../../../core/providers/database_providers.dart';
import '../../../core/providers/subscription_provider.dart';
import '../../../core/theme/finella_colors.dart';
import '../../../shared/widgets/goal_detail_sheet.dart';
import 'widgets/milestone_popup.dart';
import '../models/goal_model.dart';
import '../providers/goals_provider.dart';
import 'widgets/goal_card.dart';

GoalModel _toGoalModel(Goal g) => GoalModel(
      id: g.id.toString(),
      name: g.name,
      savedAmount: g.savedAmount,
      targetAmount: g.targetAmount,
      targetDate: g.targetDate,
      remindersEnabled: g.remindersEnabled,
    );

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(allGoalsProvider);
    final remindersEnabled =
        ref.watch(goalsProvider.select((s) => s.remindersEnabled));
    final notifier = ref.read(goalsProvider.notifier);
    final goalDao = ref.read(goalDaoProvider);
    final isPremium = ref.watch(isPremiumProvider);

    final dbGoals = goalsAsync.asData?.value ?? [];
    final goals = dbGoals.map(_toGoalModel).toList();

    return Scaffold(
      backgroundColor: FinellaColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'My Goals',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAddGoalSheet(context, goalDao),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: FinellaColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.add, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'New Goal',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Premium banner (free users)
            if (!isPremium)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FinellaColors.gold),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Color(0xFF92400E), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Upgrade to Premium for AI tips on every goal',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Loading state
            if (goalsAsync.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Goals list
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final goal = goals[index];
                      return GestureDetector(
                        onTap: () => showGoalDetail(
                          context: context,
                          ref: ref,
                          goal: dbGoals[index],
                        ),
                        child: GoalCard(goal: goal, isPremium: isPremium),
                      );
                    },
                    childCount: goals.length,
                  ),
                ),
              ),

              // Reminders toggle
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_outlined,
                            color: Color(0xFF2E7D32), size: 22),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Goal Reminders',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111827),
                                ),
                              ),
                              Text(
                                'Get notified about your savings progress',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: remindersEnabled,
                          onChanged: notifier.toggleReminders,
                          activeThumbColor: FinellaColors.primary,
                          activeTrackColor: const Color(0xFF2E7D32),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddGoalSheet(BuildContext context, GoalDao goalDao) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final savedCtrl = TextEditingController();

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
            const Text(
              'New Goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 20),
            _SheetField(
                controller: nameCtrl,
                label: 'Goal Name',
                hint: 'e.g. iPhone 16'),
            const SizedBox(height: 12),
            _SheetField(
                controller: targetCtrl,
                label: 'Target Amount (₹)',
                hint: '0',
                numeric: true),
            const SizedBox(height: 12),
            _SheetField(
                controller: savedCtrl,
                label: 'Already Saved (₹)',
                hint: '0',
                numeric: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FinellaColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final target = double.tryParse(targetCtrl.text) ?? 0;
                  final saved = double.tryParse(savedCtrl.text) ?? 0;
                  if (name.isEmpty || target <= 0) return;
                  await goalDao.insertGoal(GoalsCompanion.insert(
                    name: name,
                    targetAmount: target,
                    savedAmount: Value(saved),
                  ));
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  // Trigger milestone popup if initial savings cross a threshold
                  if (saved > 0 && context.mounted) {
                    checkAndShowMilestone(
                      context: context,
                      goalName: name,
                      oldSaved: 0,
                      newSaved: saved,
                      targetAmount: target,
                    );
                  }
                },
                child: const Text(
                  'Add Goal',
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
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool numeric;

  const _SheetField({
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
          keyboardType: numeric ? TextInputType.number : TextInputType.text,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
