import 'package:flutter/material.dart';

// ── Shared palette / formatting for the merchant-style transaction list ──────
// Used by both the Activity history and the Gmail import results so the two
// lists render identically.

const _avatarPalette = [
  Color(0xFF78909C), // blue grey
  Color(0xFF8D6E63), // brown
  Color(0xFF7986CB), // indigo
  Color(0xFF4DB6AC), // teal
  Color(0xFFAED581), // light green
  Color(0xFFFFB74D), // orange
  Color(0xFFF06292), // pink
  Color(0xFF9575CD), // purple
];

/// Deterministic avatar colour derived from the merchant name, so the same
/// merchant always gets the same colour.
Color merchantAvatarColor(String name) =>
    _avatarPalette[name.isEmpty ? 0 : name.codeUnitAt(0) % _avatarPalette.length];

/// Up to two uppercase initials from a merchant name.
String merchantInitials(String name) {
  final n = name.trim();
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
}

const _kMonthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];
const _kMonthsFull = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE',
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER'
];

/// e.g. `26 Jun '26`
String formatTxDate(DateTime d) =>
    "${d.day} ${_kMonthsShort[d.month - 1]} '${(d.year % 100).toString().padLeft(2, '0')}";

/// e.g. `JUNE 2026` — used for month section headers.
String monthSectionLabel(DateTime d) => '${_kMonthsFull[d.month - 1]} ${d.year}';

/// Indian-grouped amount with two decimals, e.g. `1,00,000.00`.
/// Currency symbol for an ISO code — defaults to ₹ for INR / unknown codes.
String currencySymbol(String? currency) {
  switch ((currency ?? 'INR').toUpperCase()) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'AED':
      return 'AED ';
    case 'SGD':
      return 'S\$';
    case 'AUD':
      return 'A\$';
    case 'CAD':
      return 'C\$';
    case 'JPY':
      return '¥';
    default:
      return '₹';
  }
}

String formatIndianAmount(double amount) {
  final v = amount.abs();
  var whole = v.truncate();
  var paise = ((v - whole) * 100).round();
  if (paise == 100) {
    whole += 1;
    paise = 0;
  }
  final s = whole.toString();
  String grouped;
  if (s.length <= 3) {
    grouped = s;
  } else {
    final last3 = s.substring(s.length - 3);
    var head = s.substring(0, s.length - 3);
    final groups = <String>[];
    while (head.length > 2) {
      groups.insert(0, head.substring(head.length - 2));
      head = head.substring(0, head.length - 2);
    }
    if (head.isNotEmpty) groups.insert(0, head);
    grouped = '${groups.join(',')},$last3';
  }
  return '$grouped.${paise.toString().padLeft(2, '0')}';
}

/// Section header in the grouped list, e.g. `JUNE 2026`.
class MerchantSectionHeader extends StatelessWidget {
  final String label;
  const MerchantSectionHeader({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF9E9E9E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// A single transaction row matching the reference design: a coloured initials
/// avatar with a small source badge, the merchant name + lowercase category,
/// and the amount with the date underneath.
class MerchantTransactionRow extends StatelessWidget {
  final String name;
  final String category;
  final double amount;
  final bool isIncome;
  final DateTime date;

  /// Bank/wallet logo asset for the small bottom-left badge.
  final String? logoAsset;

  /// Import provenance ('sms' | 'email' | null) — drives the badge when there
  /// is no [logoAsset].
  final String? source;

  /// Optional leading widget (e.g. a selection checkbox).
  final Widget? leading;

  final bool showDivider;

  /// Colour of the row divider. Defaults to a light grey.
  final Color dividerColor;
  final VoidCallback? onTap;

  /// When true, expenses are shown in red (and income in green) — the older
  /// debit/credit colour scheme. Defaults to false (expense in dark grey, per
  /// the reference list design).
  final bool redExpense;

  /// Optional third line under the category (e.g. the account / card number).
  final String? subtitle;

  /// ISO currency code — picks the symbol ($ for USD, € EUR, £ GBP, else ₹).
  final String currency;

  const MerchantTransactionRow({
    super.key,
    required this.name,
    required this.category,
    required this.amount,
    required this.isIncome,
    required this.date,
    this.logoAsset,
    this.source,
    this.leading,
    this.showDivider = true,
    this.dividerColor = const Color(0xFFEEEEEE),
    this.onTap,
    this.redExpense = false,
    this.subtitle,
    this.currency = 'INR',
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'Unknown';
    final sign = isIncome ? '+' : (redExpense ? '-' : '');
    final amountText = '$sign${currencySymbol(currency)}${formatIndianAmount(amount)}';
    // Avatar (16) + 46 + gap (12) = 74; offset by the leading widget if present.
    final dividerIndent = leading == null ? 74.0 : 74.0 + 36.0;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          _MerchantAvatar(
            name: displayName,
            logoAsset: logoAsset,
            source: source,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  category.toLowerCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF9E9E9E),
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9E9E9E),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isIncome
                      ? const Color(0xFF2E7D32) // credit / income → green
                      : redExpense
                          ? const Color(0xFFEF4444) // debit / expense → red
                          : const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatTxDate(date),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9E9E9E),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Column(
      children: [
        onTap == null
            ? row
            : InkWell(onTap: onTap, child: row),
        if (showDivider)
          Divider(
            height: 0.5,
            thickness: 0.5,
            indent: dividerIndent,
            endIndent: 0,
            color: dividerColor,
          ),
      ],
    );
  }
}

class _MerchantAvatar extends StatelessWidget {
  final String name;
  final String? logoAsset;
  final String? source;

  const _MerchantAvatar({
    required this.name,
    this.logoAsset,
    this.source,
  });

  @override
  Widget build(BuildContext context) {
    final badge = _badge();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: merchantAvatarColor(name),
            border: Border.all(color: const Color(0xFFEEEEEE), width: 1),
          ),
          alignment: Alignment.center,
          child: Text(
            merchantInitials(name),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        if (badge != null)
          Positioned(
            bottom: -2,
            left: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: badge,
            ),
          ),
      ],
    );
  }

  /// Bank logo if known, otherwise a small icon for the import source.
  Widget? _badge() {
    if (logoAsset != null) {
      return Image.asset(
        logoAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _sourceBadge() ?? const SizedBox.shrink(),
      );
    }
    return _sourceBadge();
  }

  Widget? _sourceBadge() {
    switch (source) {
      case 'email':
        return Container(
          color: const Color(0xFFEA4335),
          alignment: Alignment.center,
          child: const Icon(Icons.mail, size: 10, color: Colors.white),
        );
      case 'sms':
        return Container(
          color: const Color(0xFF22A565),
          alignment: Alignment.center,
          child: const Icon(Icons.sms, size: 9, color: Colors.white),
        );
      default:
        return null;
    }
  }
}
