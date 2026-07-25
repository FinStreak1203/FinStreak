import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../transactions/presentation/category_picker_sheet.dart';
import '../../viewmodel/budgets_view_model.dart';

/// Bottom sheet for creating or editing a budget.
///
/// Pass [budget] to edit an existing one (locks the category and enables the
/// Delete action). Persists through [BudgetsViewModel].
class NewBudgetSheet extends ConsumerStatefulWidget {
  final Budget? budget;
  const NewBudgetSheet({super.key, this.budget});

  @override
  ConsumerState<NewBudgetSheet> createState() => _NewBudgetSheetState();
}

/// Categories hidden from the budget picker (still available for transactions).
const _excludedBudgetCategoryIds = {
  'cafe',
  'cell_phone',
  'clothing',
  'personal',
  'kids',
  'pet',
  'charity',
  'bar',
  'home_repair',
  'water',
  'heating',
  'credit_card',
};

/// Expense categories shown when creating a budget.
final List<CategoryItem> budgetCategories = allCategories
    .where((c) => !_excludedBudgetCategoryIds.contains(c.id))
    .toList();

class _NewBudgetSheetState extends ConsumerState<NewBudgetSheet> {
  String? _categoryId;
  String? _categoryName;
  late final TextEditingController _limitCtrl;
  bool _isSaving = false;

  bool get _isEditing => widget.budget != null;

  @override
  void initState() {
    super.initState();
    final b = widget.budget;
    _categoryId = b?.categoryId;
    _categoryName = b?.categoryName;
    _limitCtrl = TextEditingController(
      text: b == null ? '' : _trimZeros(b.limitAmount),
    );
  }

  static String _trimZeros(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _limitCtrl.dispose();
    super.dispose();
  }

  CategoryItem? get _categoryItem {
    for (final c in allCategories) {
      if (c.id == _categoryId) return c;
    }
    return null;
  }

  void _pickCategory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7FAF4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, controller) => CategoryPickerSheet(
          scrollCtrl: controller,
          categories: budgetCategories,
          onSelect: (id, name) => setState(() {
            _categoryId = id;
            _categoryName = name;
          }),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (_categoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a category'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    final limit = double.tryParse(_limitCtrl.text.trim()) ?? 0;
    if (limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a budget amount greater than 0'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    final vm = ref.read(budgetsViewModelProvider);
    if (_isEditing) {
      await vm.updateBudget(widget.budget!, limit);
    } else {
      final month = ref.read(budgetMonthProvider);
      await vm.addBudget(
        categoryId: _categoryId!,
        categoryName: _categoryName ?? _categoryId!,
        limitAmount: limit,
        year: month.year,
        month: month.month,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final b = widget.budget;
    if (b == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete budget?'),
        content: Text(
          'The “${b.categoryName}” budget will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(budgetsViewModelProvider).deleteBudget(b.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final cat = _categoryItem;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Edit budget' : 'New budget',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Category ──────────────────────────────
                const _FieldLabel('Category'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isEditing ? null : _pickCategory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isEditing
                          ? const Color(0xFFF7FAF4)
                          : Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        if (cat != null) ...[
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: cat.bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat.icon,
                                size: 18, color: cat.iconColor),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            _categoryName ?? 'Select category',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _categoryName != null
                                  ? const Color(0xFF111827)
                                  : const Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                        if (!_isEditing)
                          const Icon(Icons.chevron_right,
                              color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Monthly limit ─────────────────────────
                const _FieldLabel('Monthly limit'),
                const SizedBox(height: 8),
                TextField(
                  controller: _limitCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF111827),
                  ),
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    prefixStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                    hintText: '0',
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFFD1D5DB),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF2E7D32), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Save ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isEditing ? 'Update Budget' : 'Save budget',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _confirmDelete,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(
                            color: Color(0xFFEF4444), width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Delete Budget',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
      );
}
