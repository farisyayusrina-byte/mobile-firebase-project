import 'package:firebase_auth/firebase_auth.dart';

import 'firestore_service.dart';

class AuthService {
  AuthService({
    FirebaseAuth? auth,
    FirestoreService? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirestoreService();

  final FirebaseAuth _auth;
  final FirestoreService _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = displayName.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );

    final user = credential.user;
    if (user != null) {
      await user.updateDisplayName(trimmedName);
      await _firestore.saveUserProfile(
        userId: user.uid,
        email: user.email ?? trimmedEmail,
        displayName: trimmedName,
      );
    }

    return credential;
  }

  /// Pastikan profil wujud dalam Firestore (log masuk / pengguna lama).
  Future<void> syncUserProfile(User user) async {
    await _firestore.saveUserProfile(
      userId: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();
}
