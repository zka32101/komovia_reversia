import 'package:firebase_auth/firebase_auth.dart';

import 'account_data_deletion_service.dart';

/// Firebase Auth wrapper. Same role as komovia_shogi's/komovia_go's
/// `AuthService`.
///
/// The app signs in anonymously on first launch so every feature has a
/// stable uid immediately. An anonymous uid is lost for good on reinstall or
/// device change — and with it the player's records AND the paid lifetime
/// unlock (`premium_entitlements/{uid}`). [linkWithEmail] upgrades the
/// current anonymous user in place (`linkWithCredential` — a LINK, so the uid
/// and everything keyed by it is kept), and [signInWithEmail] lets the player
/// get back to that same uid on a new device. Ported from komovia_go's
/// `linkAnonymousToEmail`/`deleteAccount`.
class AuthService {
  AuthService({
    FirebaseAuth? auth,
    AccountDataDeletionService Function()? dataDeletion,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _dataDeletion = dataDeletion ?? (() => AccountDataDeletionService());

  final FirebaseAuth _auth;
  final AccountDataDeletionService Function() _dataDeletion;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  /// Links the current anonymous user to an email/password credential.
  /// The uid does not change, so all Firestore data and the premium
  /// entitlement stay attached to it.
  Future<User> linkWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AuthServiceException('no-anonymous-user');
    }
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      final result = await user.linkWithCredential(credential);
      return result.user ?? user;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(e.code);
    }
  }

  /// Signs in to an already-linked account (e.g. on a new device). This
  /// replaces the current anonymous uid, so whatever was played on this
  /// device before signing in is not carried over.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) throw const AuthServiceException('unknown');
      return user;
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(e.code);
    }
  }

  /// Permanently deletes the account: the user's own Firestore data first
  /// (once the auth user is gone the security rules no longer allow it),
  /// then the Firebase Auth user. Data cleanup is best effort and idempotent,
  /// so a failed auth delete (e.g. `requires-recent-login`) can be retried.
  Future<List<String>> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthServiceException('no-current-user');
    final failed = await _dataDeletion().deleteAllUserData(user.uid);
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthServiceException(e.code);
    }
    return failed;
  }

  Future<void> signOut() => _auth.signOut();
}

/// Carries a Firebase Auth error code (e.g. `email-already-in-use`,
/// `weak-password`, `requires-recent-login`) for the UI to localize.
class AuthServiceException implements Exception {
  const AuthServiceException(this.code);

  final String code;

  @override
  String toString() => 'AuthServiceException($code)';
}
