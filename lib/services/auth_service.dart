import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Web client ID from the Firebase project's OAuth configuration.
  // Required on Android as a fallback when the SHA-1 fingerprint in
  // google-services.json doesn't match the current build keystore.
  static const String _webClientId =
      '942480274228-v4v02d5f7rngv1ltrafoupeomtiotm0m.apps.googleusercontent.com';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email'],
    serverClientId: _webClientId,
  );

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Signs in with Google.
  ///
  /// Returns `null` only when the user **cancels** the sign-in flow.
  /// All other errors (network, config, FirebaseAuthException) are
  /// **propagated to the caller** so they can show a meaningful error
  /// message instead of a generic "sign-in failed" toast.
  Future<UserCredential?> signInWithGoogle() async {
    // Trigger the authentication flow
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

    // User cancelled the sign-in → return null (not an error)
    if (googleUser == null) {
      return null;
    }

    // Obtain the auth details from the request
    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Create a new credential
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Sign in and return the UserCredential.
    // Any FirebaseAuthException, PlatformException, or network error
    // propagates to the caller automatically.
    return await _auth.signInWithCredential(credential);
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }
    }
  }

  // Check if user is first time signing in
  bool isFirstTimeUser(User user) {
    // Check if user's metadata creation time is recent (within last 5 minutes)
    final DateTime now = DateTime.now();
    final DateTime? creationTime = user.metadata.creationTime;

    if (creationTime == null) return true;

    final Duration difference = now.difference(creationTime);
    return difference.inMinutes < 5;
  }
}
