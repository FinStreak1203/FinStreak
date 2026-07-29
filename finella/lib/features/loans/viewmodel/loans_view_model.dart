import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/providers/database_providers.dart';

class LoansState {
  final List<Loan> loans;
  final bool isLoading;

  const LoansState({this.loans = const [], this.isLoading = true});

  LoansState copyWith({List<Loan>? loans, bool? isLoading}) {
    return LoansState(
      loans: loans ?? this.loans,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class LoansNotifier extends StateNotifier<LoansState> {
  final Ref _ref;

  LoansNotifier(this._ref) : super(const LoansState()) {
    _listen();
  }

  void _listen() {
    _ref.listen<AsyncValue<List<Loan>>>(allLoansProvider, (_, next) {
      next.whenData((loans) {
        state = state.copyWith(loans: loans, isLoading: false);
      });
    }, fireImmediately: true);
  }

  Future<void> addLoan(Loan loan) async {
    await _ref.read(loanDaoProvider).insert(loan.toCompanion());
  }

  Future<void> updateLoan(Loan loan) async {
    await _ref.read(loanDaoProvider).update(loan);
  }

  Future<void> deleteLoan(int id) async {
    await _ref.read(loanDaoProvider).delete(id);
  }

  Future<void> markMonthlyReconciled(int loanId) async {
    final loan = state.loans.firstWhere((l) => l.id == loanId);
    final updated = loan.copyWith(monthlyReconciledAt: DateTime.now());
    await updateLoan(updated);
  }
}

final loansProvider = StateNotifierProvider<LoansNotifier, LoansState>((ref) {
  return LoansNotifier(ref);
});