import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'study_state_manager.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _isMockMode = false;
  bool get isMockMode => _isMockMode;

  /// Check if Firebase is initialized. If not, fallback to mock mode.
  Future<void> initialize() async {
    try {
      // Check if Firebase is already initialized by checking the apps list.
      if (Firebase.apps.isEmpty) {
        // This will throw if not configured, allowing us to fall back to mock mode.
        await Firebase.initializeApp();
      }
      // Initialize GoogleSignIn
      await _googleSignIn.initialize();
      debugPrint("AuthService: Firebase and GoogleSignIn initialized successfully.");
    } catch (e) {
      _isMockMode = true;
      debugPrint("AuthService WARNING: Firebase/GoogleSignIn initialization failed ($e). Falling back to Mock Auth Mode.");
    }
  }

  /// Check if user is currently signed in.
  User? get currentUser {
    if (_isMockMode) return null;
    return _auth.currentUser;
  }

  /// Sign in with Google.
  Future<UserCredential?> signInWithGoogle() async {
    if (_isMockMode) {
      debugPrint("AuthService: Performing Mock Google Sign-In...");
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 800));
      
      // Update local StudyStateManager state
      final state = StudyStateManager.instance;
      state.userName = "Lumina Scholar";
      state.userEmail = "scholar@lumina.ai";
      // Use the premium green mascot as default profile photo
      state.userMascot = "assets/images/mascot_girl_login.png";
      await state.login(true);
      
      return null;
    }

    try {
      // Trigger the Google Sign-In flow (authenticate for v7.0.0+)
      final googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        debugPrint("AuthService: Google Sign-In cancelled by user.");
        return null;
      }

      // Obtain authentication and authorization details
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final googleAuthorization = await googleUser.authorizationClient.authorizationForScopes([
        'email',
        'profile',
      ]);

      // Create a new credential
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuthorization?.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Sync user details to StudyStateManager
        final state = StudyStateManager.instance;
        state.userName = user.displayName ?? "Lumina Scholar";
        state.userEmail = user.email ?? "";
        if (user.photoURL != null && user.photoURL!.isNotEmpty) {
          state.userMascot = user.photoURL!;
        } else {
          state.userMascot = "assets/images/mascot_girl_login.png";
        }
        await state.login(true);
      }

      return userCredential;
    } catch (e) {
      debugPrint("AuthService ERROR: Google Sign-In failed: $e");
      rethrow;
    }
  }

  /// Sign out.
  Future<void> signOut() async {
    final state = StudyStateManager.instance;
    await state.logout();

    if (_isMockMode) {
      debugPrint("AuthService: Mock Sign-Out successful.");
      return;
    }

    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
      debugPrint("AuthService: Firebase Sign-Out successful.");
    } catch (e) {
      debugPrint("AuthService ERROR: Sign-Out failed: $e");
    }
  }
}
