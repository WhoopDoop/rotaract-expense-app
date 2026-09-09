import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/drive.file'],
  );

  GoogleSignInAccount? _user;
  GoogleSignInAccount? get user => _user;
  bool get isSignedIn => _user != null;
  String? get userId => _user?.id;

  AuthProvider() {
    // Try to sign in silently if the user has signed in before.
    _googleSignIn.signInSilently().then((account) {
      _user = account;
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    try {
      _user = await _googleSignIn.signIn();
      notifyListeners();
    } catch (e) {
      debugPrint('Sign-in failed: $e');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _user = null;
    notifyListeners();
  }

  GoogleSignIn get signInInstance => _googleSignIn;
}