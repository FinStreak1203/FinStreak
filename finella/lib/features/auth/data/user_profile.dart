import 'package:firebase_auth/firebase_auth.dart';

/// The signed-in user's profile, merged from the Firestore `users/{uid}` doc
/// (firstName/lastName/phone, written at email sign-up) and FirebaseAuth
/// (email, displayName, phone) so Google/Guest users still show sensible data.
class UserProfile {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String photoUrl;
  final bool isGuest;

  const UserProfile({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.isGuest,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    final combined = (f + l).toUpperCase();
    if (combined.isNotEmpty) return combined;
    if (email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }

  factory UserProfile.fromSources({
    required User user,
    Map<String, dynamic>? doc,
  }) {
    var first = (doc?['firstName'] as String?)?.trim() ?? '';
    var last = (doc?['lastName'] as String?)?.trim() ?? '';

    // Google / older accounts: split the display name when no profile doc.
    if (first.isEmpty && last.isEmpty &&
        (user.displayName?.trim().isNotEmpty ?? false)) {
      final parts = user.displayName!.trim().split(RegExp(r'\s+'));
      first = parts.first;
      last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    return UserProfile(
      firstName: first,
      lastName: last,
      email: user.email ?? (doc?['email'] as String?) ?? '',
      phone: (doc?['phone'] as String?) ?? user.phoneNumber ?? '',
      photoUrl: (doc?['photoUrl'] as String?) ?? user.photoURL ?? '',
      isGuest: user.isAnonymous,
    );
  }
}
