import 'package:flutter/material.dart';
import '../../models/detected_account.dart';

const _kPrimary = Color(0xFF2E7D32);

/// Bottom sheet shown when the email import detects accounts not yet in the
/// user's Accounts tab. Returns the list of accounts the user chose to add
/// (empty list if they tapped Skip / dismissed).
class NewAccountsDetectedSheet extends StatefulWidget {
  final List<DetectedAccount> accounts;
  const NewAccountsDetectedSheet({super.key, required this.accounts});

  @override
  State<NewAccountsDetectedSheet> createState() =>
      _NewAccountsDetectedSheetState();
}

class _NewAccountsDetectedSheetState extends State<NewAccountsDetectedSheet> {
  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.accounts.where((a) => a.isSelected).length;

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
            padding: EdgeInsets.fromLTRB(20, 0, 20, 2),
            child: Text(
              '🏦  New Accounts Detected!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Add these to your Accounts tab?',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              itemCount: widget.accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final a = widget.accounts[i];
                return _AccountRow(
                  account: a,
                  onChanged: (v) => setState(() => a.isSelected = v),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(
                        <DetectedAccount>[], // Skip → create nothing
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6B7280),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Skip',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: selectedCount == 0
                          ? null
                          : () => Navigator.of(context).pop(
                                widget.accounts
                                    .where((a) => a.isSelected)
                                    .toList(),
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        disabledBackgroundColor: const Color(0xFF9CA3AF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        'Add Accounts${selectedCount > 0 ? ' ($selectedCount)' : ''}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  final DetectedAccount account;
  final ValueChanged<bool> onChanged;
  const _AccountRow({required this.account, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onChanged(!account.isSelected),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEFF1F0)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 26,
                height: 26,
                child: Checkbox(
                  value: account.isSelected,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: _kPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                padding: const EdgeInsets.all(5),
                child: Image.asset(
                  account.imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.account_balance_rounded,
                    color: Color(0xFF6B7280),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.bankName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          account.accountNumber,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        account.typeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
