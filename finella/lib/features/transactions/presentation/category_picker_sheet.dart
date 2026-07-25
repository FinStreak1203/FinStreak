import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/category_options.dart';
import '../../../core/database/category_dao.dart';
import '../../../core/providers/database_providers.dart';
import 'new_category_sheet.dart';

class CategoryItem {
  final String id;
  final String name;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

// ── Income categories ─────────────────────────────────────────
final List<CategoryItem> incomeCategories = [
  const CategoryItem(
    id: 'salary',
    name: 'Salary',
    icon: Icons.account_balance_rounded,
    bgColor: Color(0xFFFFFBE6),
    iconColor: Color(0xFFEAB308),
  ),
  const CategoryItem(
    id: 'business',
    name: 'Business',
    icon: Icons.business_center_rounded,
    bgColor: Color(0xFFF5F3FF),
    iconColor: Color(0xFF7C3AED),
  ),
  const CategoryItem(
    id: 'investment',
    name: 'Investment',
    icon: Icons.trending_up_rounded,
    bgColor: Color(0xFFE6F0FF),
    iconColor: Color(0xFF3B82F6),
  ),
  const CategoryItem(
    id: 'sale',
    name: 'Sale',
    icon: Icons.sell_rounded,
    bgColor: Color(0xFFF5F3FF),
    iconColor: Color(0xFF8B5CF6),
  ),
  const CategoryItem(
    id: 'gift',
    name: 'Gift',
    icon: Icons.card_giftcard_rounded,
    bgColor: Color(0xFFE6FAF2),
    iconColor: Color(0xFF10B981),
  ),
  const CategoryItem(
    id: 'rent_income',
    name: 'Rent',
    icon: Icons.home_rounded,
    bgColor: Color(0xFFFFF0F0),
    iconColor: Color(0xFFEF4444),
  ),
  const CategoryItem(
    id: 'freelance',
    name: 'Freelance',
    icon: Icons.laptop_rounded,
    bgColor: Color(0xFFE6F0FF),
    iconColor: Color(0xFF3B82F6),
  ),
  const CategoryItem(
    id: 'bonus',
    name: 'Bonus',
    icon: Icons.stars_rounded,
    bgColor: Color(0xFFFFFBE6),
    iconColor: Color(0xFFD97706),
  ),
  const CategoryItem(
    id: 'dividend',
    name: 'Dividend',
    icon: Icons.bar_chart_rounded,
    bgColor: Color(0xFFE6FAF2),
    iconColor: Color(0xFF10B981),
  ),
  const CategoryItem(
    id: 'refund',
    name: 'Refund',
    icon: Icons.replay_rounded,
    bgColor: Color(0xFFEEF2FF),
    iconColor: Color(0xFF6366F1),
  ),
  const CategoryItem(
    id: 'interest',
    name: 'Interest',
    icon: Icons.percent_rounded,
    bgColor: Color(0xFFCCFBF1),
    iconColor: Color(0xFF14B8A6),
  ),
  const CategoryItem(
    id: 'opening_balance',
    name: 'Opening Balance',
    icon: Icons.account_balance_wallet_rounded,
    bgColor: Color(0xFFE6FAF2),
    iconColor: Color(0xFF2E7D32),
  ),
  const CategoryItem(
    id: 'income_other',
    name: 'Other',
    icon: Icons.more_horiz_rounded,
    bgColor: Color(0xFFF3F4F6),
    iconColor: Color(0xFF6B7280),
  ),
];

// ── Expense categories ────────────────────────────────────────
final List<CategoryItem> allCategories = [
  const CategoryItem(
    id: 'food_drink',
    name: 'Food & Drink',
    icon: Icons.restaurant_rounded,
    bgColor: Color(0xFFFFF0E6),
    iconColor: Color(0xFFF97316),
  ),
  const CategoryItem(
    id: 'groceries',
    name: 'Groceries',
    icon: Icons.shopping_cart_rounded,
    bgColor: Color(0xFFE6FAF2),
    iconColor: Color(0xFF10B981),
  ),
  const CategoryItem(
    id: 'cafe',
    name: 'Cafe',
    icon: Icons.coffee_rounded,
    bgColor: Color(0xFFFAF0E6),
    iconColor: Color(0xFFD97706),
  ),
  const CategoryItem(
    id: 'transport',
    name: 'Transport',
    icon: Icons.directions_car_rounded,
    bgColor: Color(0xFFE6F0FF),
    iconColor: Color(0xFF3B82F6),
  ),
  const CategoryItem(
    id: 'bills',
    name: 'Bills',
    icon: Icons.receipt_long_rounded,
    bgColor: Color(0xFFEEF2FF),
    iconColor: Color(0xFF6366F1),
  ),
  const CategoryItem(
    id: 'entertainment',
    name: 'Entertainment',
    icon: Icons.movie_rounded,
    bgColor: Color(0xFFF5F3FF),
    iconColor: Color(0xFF7C3AED),
  ),
  const CategoryItem(
    id: 'health',
    name: 'Health',
    icon: Icons.favorite_rounded,
    bgColor: Color(0xFFFFF0F0),
    iconColor: Color(0xFFEF4444),
  ),
  const CategoryItem(
    id: 'shopping',
    name: 'Shopping',
    icon: Icons.shopping_bag_rounded,
    bgColor: Color(0xFFCCFBF1),
    iconColor: Color(0xFF14B8A6),
  ),
  const CategoryItem(
    id: 'education',
    name: 'Education',
    icon: Icons.school_rounded,
    bgColor: Color(0xFFEEF2FF),
    iconColor: Color(0xFF6366F1),
  ),
  const CategoryItem(
    id: 'utilities',
    name: 'Utilities',
    icon: Icons.bolt_rounded,
    bgColor: Color(0xFFFFFBE6),
    iconColor: Color(0xFFEAB308),
  ),
  const CategoryItem(
    id: 'insurance',
    name: 'Insurance',
    icon: Icons.shield_rounded,
    bgColor: Color(0xFFE6FAF2),
    iconColor: Color(0xFF059669),
  ),
  const CategoryItem(
    id: 'finance',
    name: 'Finance',
    icon: Icons.savings_rounded,
    bgColor: Color(0xFFEEF2FF),
    iconColor: Color(0xFF4F46E5),
  ),
  const CategoryItem(
    id: 'travel',
    name: 'Travel',
    icon: Icons.flight_rounded,
    bgColor: Color(0xFFE6F0FF),
    iconColor: Color(0xFF3B82F6),
  ),
  const CategoryItem(
    id: 'other',
    name: 'Other',
    icon: Icons.more_horiz_rounded,
    bgColor: Color(0xFFF3F4F6),
    iconColor: Color(0xFF6B7280),
  ),
];

class CategoryPickerSheet extends ConsumerWidget {
  final ScrollController scrollCtrl;
  final void Function(String id, String name) onSelect;
  /// 'expense', 'income', or 'transfer'
  final String type;

  /// Optional explicit category list. When provided, overrides the
  /// type-based default (used by Budgets to show a curated subset).
  final List<CategoryItem>? categories;

  const CategoryPickerSheet({
    super.key,
    required this.scrollCtrl,
    required this.onSelect,
    this.type = 'expense',
    this.categories,
  });

  /// Maps a stored [CustomCategory] to a display [CategoryItem].
  static CategoryItem _toItem(CustomCategory c) {
    final col = categoryColorFor(c.colorKey);
    return CategoryItem(
      id: c.id,
      name: c.name,
      icon: categoryIconFor(c.iconKey),
      bgColor: col.bg,
      iconColor: col.fg,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // An explicit list (Budgets) overrides everything — no custom rows / Add.
    final usingDefault = categories == null;
    final base = categories ??
        (type == 'income' ? incomeCategories : allCategories);

    // Merge the user's custom categories for this type.
    final custom = usingDefault
        ? (ref.watch(customCategoriesProvider).valueOrNull ?? const [])
            .where((c) =>
                c.type == (type == 'income' ? 'income' : 'expense'))
            .map(_toItem)
            .toList()
        : const <CategoryItem>[];
    final cats = [...base, ...custom];
    final showAdd = usingDefault && type != 'transfer';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
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

        // Title
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Select category',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Category grid
        Expanded(
          child: GridView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: cats.length + (showAdd ? 1 : 0),
            itemBuilder: (ctx, i) {
              // Trailing "＋ Add" tile.
              if (showAdd && i == cats.length) {
                return _AddCategoryTile(
                  onTap: () async {
                    final created =
                        await showModalBottomSheet<CustomCategory>(
                      context: ctx,
                      isScrollControlled: true,
                      backgroundColor: Colors.white,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) => NewCategorySheet(type: type),
                    );
                    if (created != null && ctx.mounted) {
                      onSelect(created.id, created.name);
                      Navigator.of(ctx).pop(); // close the picker
                    }
                  },
                );
              }
              final cat = cats[i];
              return _CategoryTile(
                cat: cat,
                onTap: () {
                  onSelect(cat.id, cat.name);
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final CategoryItem cat;
  final VoidCallback onTap;

  const _CategoryTile({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cat.bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(cat.icon, color: cat.iconColor, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            cat.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// The trailing tile that opens the "New Category" form.
class _AddCategoryTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DottedBorderBox(
            child: const Icon(Icons.add_rounded,
                color: Color(0xFF2E7D32), size: 28),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2E7D32),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A 64×64 rounded box with a dashed green border for the Add tile.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5E4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF9CCC9C), width: 1.4),
      ),
      child: child,
    );
  }
}
