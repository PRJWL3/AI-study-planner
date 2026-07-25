import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'study_state_manager.dart';
import '../firebase_options.dart';
import 'firestore_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  AuthService._privateConstructor();
  static final AuthService instance = AuthService._privateConstructor();

  late final FirebaseAuth _auth;
  late final GoogleSignIn _googleSignIn;

  bool _isMockMode = false;
  bool get isMockMode => _isMockMode;

  /// Check if Firebase is initialized. If not, fallback to mock mode.
  Future<void> initialize() async {
    try {
      // Check if Firebase is already initialized by checking the apps list.
      if (Firebase.apps.isEmpty) {
        // Initialize with default platform options configured via FlutterFire
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      if (!kIsWeb) {
        try {
          FirebaseFirestore.instance.settings = const Settings(
            persistenceEnabled: true,
            cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
          );
        } catch (e) {
          debugPrint("AuthService WARNING: Failed to set Firestore settings: $e");
        }
      }
      _auth = FirebaseAuth.instance;
      _googleSignIn = GoogleSignIn.instance;
      // Initialize GoogleSignIn (requires clientId on Web)
      if (kIsWeb) {
        await _googleSignIn.initialize(
          clientId: '937871361250-bfkmb9d0cqbendinr69285ep580p47sj.apps.googleusercontent.com',
        );
      } else {
        await _googleSignIn.initialize();
      }

      // Listen to sign-in events (critical for Web GSI button sign-in)
      _googleSignIn.authenticationEvents.listen((GoogleSignInAuthenticationEvent event) async {
        if (event is GoogleSignInAuthenticationEventSignIn) {
          final googleUser = event.user;
          debugPrint("AuthService: authenticationEvent emitted user: ${googleUser.email}");
          try {
            final GoogleSignInAuthentication googleAuth = googleUser.authentication;
            final googleAuthorization = await googleUser.authorizationClient.authorizationForScopes([
              'email',
              'profile',
            ]);

            final AuthCredential credential = GoogleAuthProvider.credential(
              accessToken: googleAuthorization?.accessToken,
              idToken: googleAuth.idToken,
            );

            final UserCredential userCredential = await _auth.signInWithCredential(credential);
            final User? user = userCredential.user;

            if (user != null) {
              final state = StudyStateManager.instance;
              if (!state.isLoggedIn) {
                state.userName = user.displayName ?? "Lumina Scholar";
                state.userEmail = user.email ?? "";
                state.userPhotoUrl = user.photoURL ?? "";
                if (state.userMascot.isEmpty) {
                  state.userMascot = "assets/images/mascot_girl_login.png";
                }
                if (user.uid.isNotEmpty) {
                  debugPrint("AuthService: Loading synced user data from Cloud Firestore on login...");
                  await FirestoreSyncService.instance.loadUserData(user.uid);
                }
                await state.login(true);
              }
            }
          } catch (e) {
            debugPrint("AuthService ERROR: Failed to sign in to Firebase after Google auth event: $e");
          }
        }
      });

      debugPrint("AuthService: Firebase and GoogleSignIn initialized successfully.");
    } catch (e) {
      _isMockMode = true;
      debugPrint("AuthService WARNING: Firebase/GoogleSignIn initialization failed. Falling back to Mock Auth Mode.");
      try {
        debugPrint("Error detail: $e");
      } catch (_) {}
    }
  }

  User? get currentUser {
    if (_isMockMode) return null;
    return _auth.currentUser;
  }

  /// Awaits the first Firebase Auth state event (critical for restoring session on page reload).
  Future<User?> getOrAwaitCurrentUser() async {
    if (_isMockMode) return null;
    if (_auth.currentUser != null) {
      return _auth.currentUser;
    }
    try {
      return await _auth.authStateChanges().first.timeout(
        const Duration(milliseconds: 1500),
      );
    } catch (_) {
      return _auth.currentUser;
    }
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
      state.userPhotoUrl = "";
      // Use the premium green mascot as default profile photo
      state.userMascot = "assets/images/mascot_girl_login.png";
      await state.login(true);
      
      return null;
    }

    try {
      if (kIsWeb) {
        // Web sign-in is handled reactively via the Google GSI button (renderButton)
        debugPrint("AuthService: Programmatic sign-in called on Web. GSI button handles flow.");
        return null;
      }

      // Trigger the Google Sign-In flow (authenticate for native v7.0.0+)
      final googleUser = await _googleSignIn.authenticate();

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
        if (!state.isLoggedIn) {
          state.userName = user.displayName ?? "Lumina Scholar";
          state.userEmail = user.email ?? "";
          state.userPhotoUrl = user.photoURL ?? "";
          if (state.userMascot.isEmpty) {
            state.userMascot = "assets/images/mascot_girl_login.png";
          }
          if (user.uid.isNotEmpty) {
            debugPrint("AuthService: Loading synced user data from Cloud Firestore on login...");
            await FirestoreSyncService.instance.loadUserData(user.uid);
          }
          await state.login(true);
        }
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
