import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Handles the *additional* Gmail read-only authorization, separate from the
/// app's Google Sign-In login.
///
/// google_sign_in 7.x splits authentication (login) from authorization
/// (scopes): scopes are requested through [GoogleSignIn.authorizationClient],
/// so granting/revoking Gmail access here never disturbs the existing login.
class GmailAuthService {
  /// Scopes required to read Gmail messages.
  static const List<String> _gmailScopes = [
    'email',
    'https://www.googleapis.com/auth/gmail.readonly',
  ];

  GoogleSignInAuthorizationClient get _client =>
      GoogleSignIn.instance.authorizationClient;

  /// Prompts the user to grant the Gmail read-only scope.
  /// Returns true if granted, false if denied or on any error.
  Future<bool> requestGmailPermission() async {
    try {
      final authz = await _client.authorizeScopes(_gmailScopes);
      return authz.accessToken.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the Gmail scope is already authorized (no prompt shown).
  Future<bool> isGmailConnected() async {
    try {
      final authz = await _client.authorizationForScopes(_gmailScopes);
      return authz != null;
    } catch (_) {
      return false;
    }
  }

  /// Drops the cached Gmail authorization so the app can no longer call the
  /// Gmail API. Used when the user disconnects from Settings.
  ///
  /// This intentionally avoids `GoogleSignIn.disconnect()` — that would revoke
  /// ALL authorization and sign the Google user out, disturbing the login flow.
  Future<void> revokeGmailPermission() async {
    try {
      final authz = await _client.authorizationForScopes(_gmailScopes);
      if (authz != null) {
        await _client.clearAuthorizationToken(accessToken: authz.accessToken);
      }
    } catch (_) {
      // Ignore — nothing to revoke / already cleared.
    }
  }

  /// Returns Authorization headers for Gmail API calls, or null if the scope
  /// isn't currently authorized. Does not prompt; call
  /// [requestGmailPermission] first.
  Future<Map<String, String>?> getAuthHeaders() async {
    try {
      return await _client.authorizationHeaders(
        _gmailScopes,
        promptIfNecessary: false,
      );
    } catch (_) {
      return null;
    }
  }
}

final gmailAuthServiceProvider =
    Provider<GmailAuthService>((ref) => GmailAuthService());

/// Whether the Gmail scope is currently authorized. Invalidate after
/// connecting/disconnecting to refresh dependent UI (e.g. the Settings badge).
final gmailConnectedProvider = FutureProvider<bool>(
  (ref) => ref.read(gmailAuthServiceProvider).isGmailConnected(),
);
