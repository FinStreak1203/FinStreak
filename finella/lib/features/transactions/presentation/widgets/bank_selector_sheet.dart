import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../accounts/models/bank_model.dart';
import 'bank_logo.dart';

/// Bottom sheet that lets the user pick one of *their own* accounts for a
/// transaction.
///
/// Only accounts the user has actually added (from Settings → Account) are
/// shown — not the full list of predefined banks/wallets. Each row shows the
/// matching bank logo when one exists, otherwise a type-based icon.
class BankSelectorSheet extends ConsumerWidget {
  final void Function(String id, String name, String imagePath) onSelect;

  /// When set, the account with this id is hidden (e.g. the "From" account is
  /// excluded from the "To" picker so a transfer can't target itself).
  final String? excludeAccountId;

  const BankSelectorSheet({
    super.key,
    required this.onSelect,
    this.excludeAccountId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allAccountsProvider).valueOrNull ?? const [];
    final accounts = excludeAccountId == null
        ? all
        : all.where((a) => a.id.toString() != excludeAccountId).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Select account',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (accounts.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Text(
              'No accounts yet. Add one from Settings → Account.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF9CA3AF),
              ),
            ),
          )
        else
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                for (final account in accounts)
                  _AccountRow(
                    id: account.id.toString(),
                    name: account.name,
                    type: account.type,
                    imagePath: bankImagePathForName(account.name),
                    onSelect: onSelect,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AccountRow extends StatelessWidget {
  final String id;
  final String name;
  final String type;
  final String? imagePath;
  final void Function(String id, String name, String imagePath) onSelect;

  const _AccountRow({
    required this.id,
    required this.name,
    required this.type,
    required this.imagePath,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: imagePath != null
          ? BankLogo(imagePath: imagePath!)
          : _TypeIcon(type: type),
      title: Text(
        name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF111827),
        ),
      ),
      onTap: () {
        onSelect(id, name, imagePath ?? '');
        Navigator.of(context).pop();
      },
    );
  }
}

/// Fallback square icon for accounts that have no matching bank logo
/// (e.g. cash / custom-named accounts).
class _TypeIcon extends StatelessWidget {
  final String type;
  const _TypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final icon = switch (type) {
      'cash' => Icons.account_balance_wallet_rounded,
      'credit_card' => Icons.credit_card_rounded,
      _ => Icons.account_balance_rounded,
    };
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 22, color: const Color(0xFF3B82F6)),
    );
  }
}
