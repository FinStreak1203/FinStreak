import 'package:flutter/material.dart';

/// Curated set of icons a user may choose for a custom category.
///
/// Categories are stored by KEY (the map key), never by raw code point, so the
/// icons keep working in release builds without `--no-tree-shake-icons` — every
/// entry here is a compile-time constant that the tree-shaker can see.
const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant_rounded,
  'cart': Icons.shopping_cart_rounded,
  'bag': Icons.shopping_bag_rounded,
  'car': Icons.directions_car_rounded,
  'bus': Icons.directions_bus_rounded,
  'home': Icons.home_rounded,
  'bolt': Icons.bolt_rounded,
  'phone': Icons.smartphone_rounded,
  'wifi': Icons.wifi_rounded,
  'movie': Icons.movie_rounded,
  'games': Icons.sports_esports_rounded,
  'health': Icons.local_hospital_rounded,
  'fitness': Icons.fitness_center_rounded,
  'school': Icons.school_rounded,
  'travel': Icons.flight_rounded,
  'hotel': Icons.hotel_rounded,
  'pet': Icons.pets_rounded,
  'gift': Icons.card_giftcard_rounded,
  'savings': Icons.savings_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'bank': Icons.account_balance_rounded,
  'card': Icons.credit_card_rounded,
  'chart': Icons.trending_up_rounded,
  'star': Icons.star_rounded,
  'heart': Icons.favorite_rounded,
  'coffee': Icons.local_cafe_rounded,
  'fuel': Icons.local_gas_station_rounded,
  'tools': Icons.build_rounded,
  'briefcase': Icons.business_center_rounded,
  'tag': Icons.sell_rounded,
};

/// Resolves a stored icon key to its [IconData], falling back to a generic tag.
IconData categoryIconFor(String? key) =>
    kCategoryIcons[key] ?? Icons.category_rounded;

/// A background / foreground colour pair for a category chip.
class CategoryColor {
  final Color bg;
  final Color fg;
  const CategoryColor(this.bg, this.fg);
}

/// Curated bg/fg colour pairs a user may choose, stored by KEY.
const Map<String, CategoryColor> kCategoryColors = {
  'orange': CategoryColor(Color(0xFFFFF0E6), Color(0xFFF97316)),
  'green': CategoryColor(Color(0xFFE6FAF2), Color(0xFF10B981)),
  'blue': CategoryColor(Color(0xFFE6F0FF), Color(0xFF3B82F6)),
  'purple': CategoryColor(Color(0xFFF5F3FF), Color(0xFF7C3AED)),
  'pink': CategoryColor(Color(0xFFFFF0F0), Color(0xFFEF4444)),
  'teal': CategoryColor(Color(0xFFCCFBF1), Color(0xFF14B8A6)),
  'amber': CategoryColor(Color(0xFFFFFBE6), Color(0xFFD97706)),
  'indigo': CategoryColor(Color(0xFFEEF2FF), Color(0xFF6366F1)),
  'slate': CategoryColor(Color(0xFFF3F4F6), Color(0xFF6B7280)),
  'forest': CategoryColor(Color(0xFFE6FAF2), Color(0xFF2E7D32)),
};

/// Resolves a stored colour key to its [CategoryColor], with a neutral default.
CategoryColor categoryColorFor(String? key) =>
    kCategoryColors[key] ??
    const CategoryColor(Color(0xFFF3F4F6), Color(0xFF6B7280));
