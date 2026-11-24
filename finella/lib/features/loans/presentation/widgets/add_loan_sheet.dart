import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';
import '../../../../core/theme/finella_colors.dart';

class LoanFormSheet extends ConsumerStatefulWidget {
  final Loan? loan;

  const LoanFormSheet({super.key, this.loan});

  @override
  ConsumerState<LoanFormSheet> createState() => _LoanFormSheetState();
}

class _LoanFormSheetState extends ConsumerState<LoanFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _outstandingCtrl = TextEditingController();
  final _emiCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _tenureCtrl = TextEditingController();
  final _remainingCtrl = TextEditingController();

  String _type = 'personal';
  DateTime _startDate = DateTime.now();
  DateTime _nextDueDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.loan != null) {
      final l = widget.loan!;
      _nameCtrl.text = l.name;
      _type = l.type;
      _principalCtrl.text = l.principalAmount.toStringAsFixed(2);
      _outstandingCtrl.text = l.outstandingAmount.toStringAsFixed(2);
      _emiCtrl.text = l.emiAmount.toStringAsFixed(2);
      _rateCtrl.text = l.interestRate.toStringAsFixed(2);
      _tenureCtrl.text = l.tenureMonths.toString();
      _remainingCtrl.text = l.remainingMonths.toString();
      _startDate = l.startDate;
      _nextDueDate = l.nextDueDate;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _principalCtrl.dispose();
    _outstandingCtrl.dispose();
    _emiCtrl.dispose();
    _rateCtrl.dispose();
    _tenureCtrl.dispose();
    _remainingCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final loan = Loan(
        id: widget.loan?.id ?? 0,
        name: _nameCtrl.text.trim(),
        type: _type,
        principalAmount: double.parse(_principalCtrl.text),
        outstandingAmount: double.parse(_outstandingCtrl.text),
        emiAmount: double.parse(_emiCtrl.text),
        interestRate: double.parse(_rateCtrl.text),
        tenureMonths: int.parse(_tenureCtrl.text),
        remainingMonths: int.parse(_remainingCtrl.text),
        startDate: _startDate,
        nextDueDate: _nextDueDate,
        isActive: true,
        monthlyReconciledAt: widget.loan?.monthlyReconciledAt,
        createdAt: widget.loan?.createdAt ?? DateTime.now(),
      );

      if (widget.loan == null) {
        await ref.read(loanDaoProvider).insert(loan.toCompanion(true));
      } else {
        await ref.read(loanDaoProvider).update(loan);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.loan == null ? 'Loan added' : 'Loan updated'),
            backgroundColor: FinellaColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: FinellaColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.loan != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: FinellaColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                isEdit ? 'Edit Loan' : 'Add Loan',
                style: const TextStyle(
                  fontFamily: 'OpenSans',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: FinellaColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              // Name
              _textField(
                controller: _nameCtrl,
                label: 'Loan Name',
                hint: 'e.g., HDFC Home Loan',
                validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
              ),

              // Type
              _dropdownField(
                label: 'Loan Type',
                value: _type,
                items: const ['home', 'personal', 'vehicle', 'education', 'credit_card'],
                onChanged: (v) => setState(() => _type = v!),
              ),

              // Principal
              _textField(
                controller: _principalCtrl,
                label: 'Principal Amount',
                hint: '5000000',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // Outstanding
              _textField(
                controller: _outstandingCtrl,
                label: 'Current Outstanding',
                hint: '4200000',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // EMI
              _textField(
                controller: _emiCtrl,
                label: 'Monthly EMI',
                hint: '45000',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // Interest Rate
              _textField(
                controller: _rateCtrl,
                label: 'Interest Rate (% p.a.)',
                hint: '8.5',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // Tenure
              _textField(
                controller: _tenureCtrl,
                label: 'Total Tenure (months)',
                hint: '240',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // Remaining Months
              _textField(
                controller: _remainingCtrl,
                label: 'Remaining Months',
                hint: '180',
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),

              // Start Date
              _dateField(
                label: 'Start Date',
                value: _startDate,
                onTap: () => _pickDate(context, (d) => setState(() => _startDate = d)),
              ),

              // Next Due Date
              _dateField(
                label: 'Next EMI Due Date',
                value: _nextDueDate,
                onTap: () => _pickDate(context, (d) => setState(() => _nextDueDate = d)),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FinellaColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(
                          isEdit ? 'Update Loan' : 'Add Loan',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: FinellaColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FinellaColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinellaColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(fontSize: 16, color: FinellaColors.textPrimary),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        items: items.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t)))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: FinellaColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FinellaColors.divider)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinellaColors.primary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        style: const TextStyle(fontSize: 16, color: FinellaColors.textPrimary),
        dropdownColor: Colors.white,
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: FinellaColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: FinellaColors.divider)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FinellaColors.primary, width: 2)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          child: Text(
            '${value.day}/${value.month}/${value.year}',
            style: const TextStyle(fontSize: 16, color: FinellaColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context, void Function(DateTime) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: FinellaColors.primary)),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'home': return 'Home Loan';
      case 'personal': return 'Personal Loan';
      case 'vehicle': return 'Vehicle Loan';
      case 'education': return 'Education Loan';
      case 'credit_card': return 'Credit Card';
      default: return type;
    }
  }
}