import 'package:flutter/material.dart';
import '../../../../core/constants/transaction_tags.dart';

/// Bottom sheet that lets the user pick the tag a transaction is "for".
///
/// Pops with the chosen [TransactionTag] (or null if dismissed).
class TagSelectorSheet extends StatelessWidget {
  final String? selectedTagId;

  const TagSelectorSheet({super.key, this.selectedTagId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Select Tag',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final tag in predefinedTags)
                  _TagChip(
                    tag: tag,
                    selected: tag.id == selectedTagId,
                    onTap: () => Navigator.of(context).pop(tag),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final TransactionTag tag;
  final bool selected;
  final VoidCallback onTap;

  const _TagChip({
    required this.tag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1A3C34) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? const Color(0xFF1A3C34)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(tag.emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            Text(
              tag.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
