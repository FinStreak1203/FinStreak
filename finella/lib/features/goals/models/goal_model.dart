class GoalModel {
  final String id;
  final String name;
  final double savedAmount;
  final double targetAmount;
  final DateTime? targetDate;
  final bool remindersEnabled;
  final String? aiTip;
  final String? aiTimeline;

  GoalModel({
    required this.id,
    required this.name,
    required this.savedAmount,
    required this.targetAmount,
    this.targetDate,
    this.remindersEnabled = false,
    this.aiTip,
    this.aiTimeline,
  });

  double get percentage =>
      (savedAmount / targetAmount * 100).clamp(0, 100);

  double get remainingAmount => targetAmount - savedAmount;

  bool get bronzeReached  => percentage >= 10;
  bool get silverReached  => percentage >= 20;
  bool get goldReached    => percentage >= 50;
  bool get diamondReached => percentage >= 90;
  bool get trophyReached  => percentage >= 100;
}
