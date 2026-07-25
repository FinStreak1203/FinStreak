import 'package:flutter_test/flutter_test.dart';
import 'package:finella/core/services/category_classifier.dart';
import 'package:finella/features/transactions/presentation/category_picker_sheet.dart';

void main() {
  group('classify', () {
    test('matches merchants against the catalog', () {
      expect(CategoryClassifier.classify('Swiggy Diners')?.id, 'food_drink');
      expect(CategoryClassifier.classify('NETFLIX C')?.id, 'entertainment');
      expect(CategoryClassifier.classify('Unknown Person'), isNull);
    });

    test('interest earned is income; interest charged stays finance', () {
      // 'interest earned' must beat the generic 'interest' → finance rule.
      expect(CategoryClassifier.classify('Interest Earned')?.id, 'interest');
      expect(
        CategoryClassifier.classify('Interest Earned', type: 'income')?.id,
        'interest',
      );
      expect(CategoryClassifier.classify('Interest Charged')?.id, 'finance');
    });

    test('a type rejects a match from the wrong pool', () {
      // 'hra' (House Rent Allowance) is a substring of "andHRA Pradesh", which
      // would otherwise tag an expense with the income-only Salary category.
      expect(
        CategoryClassifier.classify('Andhra Pradesh Center', type: 'expense'),
        isNull,
      );
      // Food & Drink is expense-only, so it can't hold an income row such as a
      // refund from a food merchant.
      expect(
        CategoryClassifier.classify('Swiggy Refund', type: 'income'),
        isNull,
      );
      // A right-pool match still comes through.
      expect(
        CategoryClassifier.classify('Swiggy Diners', type: 'expense')?.id,
        'food_drink',
      );
    });
  });

  // What the import screen does — a single classify() call decides everything,
  // and id/name always come from the same catalog entry.
  test('import categorisation never yields a mismatched id/name', () {
    for (final row in [
      ('Swiggy Diners', 'expense', 'food_drink'),
      ('Riyaz Ahmad', 'expense', 'other'), // P2P transfer → no catalog match
      ('Interest Earned', 'income', 'interest'),
      ('Andhra Pradesh Center', 'expense', 'other'), // not Salary
    ]) {
      final (merchant, type, expectedId) = row;
      final cat = CategoryClassifier.classify(merchant, type: type);
      final id = cat?.id ?? 'other';
      final name = cat?.name ?? 'Other';
      expect(id, expectedId, reason: merchant);
      final pool = type == 'income' ? incomeCategories : allCategories;
      final catalogName =
          pool.firstWhere((c) => c.id == id, orElse: () => cat!).name;
      expect(name, catalogName, reason: '$merchant: id/name must agree');
    }
  });
}
