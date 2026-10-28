import 'package:firebase_auth/firebase_auth.dart';

/// Minimal Firebase Auth wrapper — anonymous sign-in only for now, enough
/// to have a stable uid for future social/PvP features. Same role as
/// komovia_shogi's/komovia_go's `AuthService`.
class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<User?> signInAnonymously() async {
    final cred = await _auth.signInAnonymously();
    return cred.user;
  }

  Future<void> signOut() => _auth.signOut();
}
