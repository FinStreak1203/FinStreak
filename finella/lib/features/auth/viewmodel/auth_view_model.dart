import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../data/auth_repository.dart';
import '../data/user_profile.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firebaseFirestoreProvider),
  ),
);

/// The app-wide auth gate: emits the current [User] (or null when signed out).
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The signed-in user's profile (firstName/lastName/email/phone). Rebuilds when
/// the auth state changes so it always reflects the current account.
final userProfileProvider = StreamProvider<UserProfile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).watchProfile();
});

/// Transient UI state for the auth screens (spinner + last error).
class AuthUiState {
  final bool isLoading;
  final String? error;
  const AuthUiState({this.isLoading = false, this.error});

  AuthUiState copyWith({bool? isLoading, String? error}) =>
      AuthUiState(isLoading: isLoading ?? this.isLoading, error: error);
}

class AuthController extends StateNotifier<AuthUiState> {
  final AuthRepository _repo;
  AuthController(this._repo) : super(const AuthUiState());

  Future<bool> signInEmail(String email, String password) =>
      _run(() => _repo.signInWithEmail(email, password));

  /// Creates the account (without signing in) and returns true on success.
  /// The caller then routes the user to the Login screen to sign in.
  Future<bool> signUpEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) =>
      _run(() async {
        await _repo.signUpWithEmail(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
        );
        return null; // no primary sign-in; user proceeds to Login
      });

  Future<bool> signInGoogle() => _run(_repo.signInWithGoogle);

  Future<bool> signInGuest() => _run(_repo.signInAnonymously);

  Future<void> sendPasswordReset(String email) async {
    try {
      await _repo.sendPasswordReset(email);
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(error: _friendly(e));
    }
  }

  Future<void> signOut() => _repo.signOut();

  /// Runs an auth action with loading + friendly error handling.
  /// Returns true on success. The [authStateProvider] stream drives navigation,
  /// so callers usually don't need the result beyond dismissing errors.
  Future<bool> _run(Future<User?> Function() action) async {
    state = const AuthUiState(isLoading: true);
    try {
      await action();
      state = const AuthUiState();
      return true;
    } on FirebaseAuthException catch (e) {
      state = AuthUiState(error: _friendly(e));
      return false;
    } on GoogleSignInException catch (e) {
      // User cancelling the Google sheet is not an error worth shouting about.
      final cancelled = e.code == GoogleSignInExceptionCode.canceled;
      state = AuthUiState(error: cancelled ? null : 'Google sign-in failed.');
      return false;
    } catch (e) {
      state = AuthUiState(error: 'Something went wrong. Please try again.');
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = state.copyWith(error: null);
  }

  String _friendly(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address looks invalid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Incorrect email or password.',
        'email-already-in-use' => 'An account already exists for that email.',
        'weak-password' => 'Password should be at least 6 characters.',
        'network-request-failed' => 'Network error. Check your connection.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        _ => e.message ?? 'Authentication failed.',
      };
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthUiState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
