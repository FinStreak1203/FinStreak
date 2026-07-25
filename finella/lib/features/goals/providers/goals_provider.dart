import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/goal_model.dart';

class GoalsState {
  final List<GoalModel> goals;
  final bool isLoading;
  final bool remindersEnabled;

  const GoalsState({
    this.goals = const [],
    this.isLoading = false,
    this.remindersEnabled = true,
  });

  GoalsState copyWith({
    List<GoalModel>? goals,
    bool? isLoading,
    bool? remindersEnabled,
  }) =>
      GoalsState(
        goals: goals ?? this.goals,
        isLoading: isLoading ?? this.isLoading,
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      );
}

class GoalsNotifier extends StateNotifier<GoalsState> {
  GoalsNotifier() : super(const GoalsState()) {
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 80));
    state = state.copyWith(
      isLoading: false,
      goals: [
        GoalModel(
          id: 'g1',
          name: 'iPhone 16 Pro',
          savedAmount: 42000,
          targetAmount: 129900,
          aiTip: 'Reducing food delivery by ₹2,000/month helps reach iPhone goal 3 months earlier.',
        ),
        GoalModel(
          id: 'g2',
          name: 'Emergency Fund',
          savedAmount: 80000,
          targetAmount: 200000,
          aiTimeline: 'Auto-calculated timeline: December 2026 at current rate.',
          aiTip: 'Cut shopping by 15% to hit Emergency Fund by March.',
        ),
        GoalModel(
          id: 'g3',
          name: 'Goa Trip',
          savedAmount: 5000,
          targetAmount: 25000,
        ),
      ],
    );
  }

  void toggleReminders(bool value) {
    state = state.copyWith(remindersEnabled: value);
  }

  Future<void> addGoal(GoalModel goal) async {
    state = state.copyWith(goals: [...state.goals, goal]);
  }

  Future<void> deleteGoal(String id) async {
    state = state.copyWith(
      goals: state.goals.where((g) => g.id != id).toList(),
    );
  }
}

final goalsProvider =
    StateNotifierProvider<GoalsNotifier, GoalsState>(
  (ref) => GoalsNotifier(),
);
