/// A tag answering "who is this expense/income for?".
class TransactionTag {
  final String id;
  final String label;
  final String emoji;

  const TransactionTag({
    required this.id,
    required this.label,
    required this.emoji,
  });
}

const List<TransactionTag> predefinedTags = [
  TransactionTag(id: 'family', label: 'Family', emoji: '👨‍👩‍👧'),
  TransactionTag(id: 'friends', label: 'Friends', emoji: '👫'),
  TransactionTag(id: 'colleagues', label: 'Colleagues', emoji: '💼'),
  TransactionTag(id: 'team_members', label: 'Team Members', emoji: '👥'),
  TransactionTag(id: 'self', label: 'Self', emoji: '🙋'),
  TransactionTag(id: 'others', label: 'Others', emoji: '🌐'),
];

/// The default tag selection ("Self").
final TransactionTag defaultTag =
    predefinedTags.firstWhere((t) => t.id == 'self');

/// Looks up a tag by [id], or `null` if not found / id is null.
TransactionTag? tagById(String? id) {
  if (id == null) return null;
  for (final t in predefinedTags) {
    if (t.id == id) return t;
  }
  return null;
}
