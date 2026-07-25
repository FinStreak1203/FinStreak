import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/category_options.dart';
import '../../../core/database/category_dao.dart';
import '../../../core/providers/database_providers.dart';

/// Bottom sheet to create a custom category (name + icon + colour). On save it
/// writes to the [CategoryDao] and pops the new [CustomCategory] so the caller
/// can select it immediately.
class NewCategorySheet extends ConsumerStatefulWidget {
  /// 'income' or 'expense' — the category is created for this transaction type.
  final String type;
  const NewCategorySheet({super.key, required this.type});

  @override
  ConsumerState<NewCategorySheet> createState() => _NewCategorySheetState();
}

class _NewCategorySheetState extends ConsumerState<NewCategorySheet> {
  final _nameCtrl = TextEditingController();
  String _iconKey = kCategoryIcons.keys.first;
  String _colorKey = kCategoryColors.keys.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final category = CustomCategory(
      id: 'cust_${const Uuid().v4().substring(0, 8)}',
      name: name,
      type: widget.type == 'income' ? 'income' : 'expense',
      iconKey: _iconKey,
      colorKey: _colorKey,
    );
    try {
      await ref.read(categoryDaoProvider).add(category);
      if (mounted) Navigator.of(context).pop(category);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the category")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFor(_colorKey);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.bg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(categoryIconFor(_iconKey), color: color.fg, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'New Category',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Category name (e.g. Subscriptions)',
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 18),
          const _Label('ICON'),
          const SizedBox(height: 8),
          _IconGrid(
            selected: _iconKey,
            color: color.fg,
            onSelect: (k) => setState(() => _iconKey = k),
          ),
          const SizedBox(height: 18),
          const _Label('COLOUR'),
          const SizedBox(height: 8),
          _ColorRow(
            selected: _colorKey,
            onSelect: (k) => setState(() => _colorKey = k),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _nameCtrl.text.trim().isEmpty || _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                disabledBackgroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Create Category',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Color(0xFF9CA3AF),
        ),
      );
}

class _IconGrid extends StatelessWidget {
  final String selected;
  final Color color;
  final ValueChanged<String> onSelect;
  const _IconGrid(
      {required this.selected, required this.color, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final keys = kCategoryIcons.keys.toList();
    return SizedBox(
      height: 112,
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: keys.length,
        itemBuilder: (ctx, i) {
          final key = keys[i];
          final isSel = key == selected;
          return GestureDetector(
            onTap: () => onSelect(key),
            child: Container(
              decoration: BoxDecoration(
                color: isSel ? color.withValues(alpha: 0.15) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSel ? color : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(kCategoryIcons[key],
                  size: 22,
                  color: isSel ? color : const Color(0xFF6B7280)),
            ),
          );
        },
      ),
    );
  }
}

class _ColorRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;
  const _ColorRow({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final keys = kCategoryColors.keys.toList();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final key in keys)
          GestureDetector(
            onTap: () => onSelect(key),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: kCategoryColors[key]!.fg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: key == selected
                      ? const Color(0xFF111827)
                      : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: key == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}
