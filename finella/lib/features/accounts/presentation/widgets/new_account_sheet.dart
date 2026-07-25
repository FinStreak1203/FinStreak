import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../viewmodel/accounts_view_model.dart';

/// Bottom sheet for creating or editing an account (Cash / Bank / Credit Card).
///
/// Persists through [AccountsViewModel]; the Accounts list updates reactively
/// once the row is written to the database. Pass [account] to edit an existing
/// account (enables the Delete action and a balance-merge-free save).
class NewAccountSheet extends ConsumerStatefulWidget {
  final Account? account;
  const NewAccountSheet({super.key, this.account});

  @override
  ConsumerState<NewAccountSheet> createState() => _NewAccountSheetState();
}

class _NewAccountSheetState extends ConsumerState<NewAccountSheet> {
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _balanceCtrl;
  bool _isSaving = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final acc = widget.account;
    _type = acc?.type ?? 'cash';
    _nameCtrl = TextEditingController(text: acc?.name ?? '');
    _balanceCtrl = TextEditingController(
      text: acc == null ? '' : _trimZeros(acc.balance),
    );
  }

  static String _trimZeros(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an account name'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);

    final balance = double.tryParse(_balanceCtrl.text.trim()) ?? 0.0;
    final vm = ref.read(accountsViewModelProvider);

    String? message;
    if (_isEditing) {
      await vm.updateAccount(
        account: widget.account!,
        name: name,
        type: _type,
        openingBalance: balance,
      );
    } else {
      final merged = await vm.addAccount(
        name: name,
        type: _type,
        openingBalance: balance,
      );
      if (merged) message = 'Added to existing "$name" account';
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final acc = widget.account;
    if (acc == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text(
          '“${acc.name}” will be removed. This cannot be undone.',
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

    await ref.read(accountsViewModelProvider).deleteAccount(acc.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
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
                  _isEditing ? 'Edit account' : 'New account',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Type selector ─────────────────────────
                Row(
                  children: [
                    _TypeCard(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Cash',
                      isSelected: _type == 'cash',
                      onTap: () => setState(() => _type = 'cash'),
                    ),
                    const SizedBox(width: 12),
                    _TypeCard(
                      icon: Icons.account_balance_outlined,
                      label: 'Bank',
                      isSelected: _type == 'bank',
                      onTap: () => setState(() => _type = 'bank'),
                    ),
                    const SizedBox(width: 12),
                    _TypeCard(
                      icon: Icons.credit_card_outlined,
                      label: 'Credit Card',
                      isSelected: _type == 'credit_card',
                      onTap: () => setState(() => _type = 'credit_card'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Account name ──────────────────────────
                const _FieldLabel('Account name'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _nameCtrl,
                  hint: 'e.g. Savings',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                // ── Opening balance ───────────────────────
                const _FieldLabel('Opening balance'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _balanceCtrl,
                  hint: '0',
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                ),
                const SizedBox(height: 24),

                // ── Save button ───────────────────────────
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
                            _isEditing ? 'Update Account' : 'Save account',
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
                        'Delete Account',
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

// ── Account type card ─────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFE5E7EB),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 26,
                color: isSelected ? Colors.white : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                      isSelected ? Colors.white : const Color(0xFF374151),
                ),
              ),
            ],
          ),
        ),
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

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Color(0xFF111827),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: Color(0xFFD1D5DB),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 1.5),
        ),
      ),
    );
  }
}
