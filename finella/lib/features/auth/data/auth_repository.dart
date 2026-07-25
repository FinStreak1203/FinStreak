import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'user_profile.dart';

/// Thin wrapper around FirebaseAuth + Google Sign-In (v7 API).
///
/// All sign-in methods return the signed-in [User]; failures throw
/// [FirebaseAuthException] (email) or [GoogleSignInException] (Google), which
/// the view-model translates into friendly messages.
class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  AuthRepository(this._auth, this._firestore);

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  /// Live profile for the current user, merging the Firestore `users/{uid}` doc
  /// with FirebaseAuth fields. Emits null when signed out.
  Stream<UserProfile?> watchProfile() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);
    return _firestore.collection('users').doc(user.uid).snapshots().map(
          (snap) => UserProfile.fromSources(user: user, doc: snap.data()),
        );
  }

  Future<User?> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user != null) await _updateLastLogin(user);
    return user;
  }

  /// Merges a lastLogin timestamp into the user's profile doc (never overwrites
  /// other fields). Best-effort — a failure must not block sign-in.
  Future<void> _updateLastLogin(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {'lastLogin': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {
      // Ignore — login still succeeds.
    }
  }

  /// Creates an account WITHOUT signing into the primary session.
  ///
  /// Uses a temporary secondary [FirebaseApp] so the auth gate doesn't drop the
  /// user straight into the app — after sign-up they return to the Login screen
  /// and sign in normally. The profile doc is written while authenticated on the
  /// secondary app (so Firestore rules pass), then the secondary app is removed.
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    FirebaseApp secondary;
    try {
      secondary = Firebase.app('signup-temp');
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: 'signup-temp',
        options: Firebase.app().options,
      );
    }

    // NOTE: we deliberately do NOT call `secondary.delete()`. Deleting a
    // FirebaseApp that owns a live Firestore instance is a known FlutterFire
    // bug on iOS — it tears down the DEFAULT app's Firestore too, which later
    // surfaces as "[cloud_firestore/unknown] FirebaseApp was deleted" on the
    // next write (e.g. onboarding's "Start tracking"). The temp app is tiny and
    // idle once signed out, and is reused on the next sign-up (see above).
    final secondaryDb = FirebaseFirestore.instanceFor(app: secondary);
    final auth = FirebaseAuth.instanceFor(app: secondary);
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user != null) {
        final fullName = '${firstName.trim()} ${lastName.trim()}'.trim();
        await user.updateDisplayName(fullName);
        await secondaryDb.collection('users').doc(user.uid).set({
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } finally {
      // Always leave the temp app signed out so its idle session can't leak
      // into anything, and so the next sign-up starts clean.
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Google Sign-In via the v7 `authenticate()` flow. Returns `null` if the
  /// platform can't surface an id token.
  ///
  /// Requires [GoogleSignIn.instance.initialize] to have been called once at
  /// startup (with the OAuth *web* client id as `serverClientId`).
  Future<User?> signInWithGoogle() async {
    final google = GoogleSignIn.instance;
    if (!google.supportsAuthenticate()) {
      throw const GoogleSignInUnsupportedException();
    }
    final account = await google.authenticate(scopeHint: const ['email']);
    final idToken = account.authentication.idToken;
    if (idToken == null) return null;

    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    if (user != null) await _saveGoogleProfile(user);
    return user;
  }

  /// Saves the Google account's details to `users/{uid}` after sign-in.
  ///
  /// Uses merge so existing data is never overwritten; `createdAt` is written
  /// only on first creation, while `lastLogin` updates every time. Best-effort.
  Future<void> _saveGoogleProfile(User user) async {
    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final snap = await docRef.get();

      final parts = (user.displayName ?? '').trim().split(RegExp(r'\s+'));
      final data = <String, dynamic>{
        'email': user.email ?? '',
        'firstName': parts.isNotEmpty ? parts.first : '',
        'lastName': parts.length > 1 ? parts.last : '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'loginType': 'google',
        'lastLogin': FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
    } catch (_) {
      // Ignore — sign-in still succeeds.
    }
  }

  Future<void> signOut() async {
    // Best-effort Google sign-out; ignore if the user never used Google.
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}

/// Thrown when the current platform doesn't support `authenticate()`
/// (e.g. web, where a rendered button flow is required instead).
class GoogleSignInUnsupportedException implements Exception {
  const GoogleSignInUnsupportedException();
  @override
  String toString() => 'Google Sign-In is not supported on this platform.';
}
