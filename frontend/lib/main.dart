import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'widgets/global_eggy.dart';
import 'services/study_state_manager.dart';

void main() {
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumina Study',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5C77), // Primary Rose
          primary: const Color(0xFFFF5C77),
          secondary: const Color(0xFF006A63), // Secondary Teal
          surface: Colors.white,
          background: const Color(0xFFF9F9FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF9F9FC), // Cool soft off-white background
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24), // 24px (rounded-xl)
            side: const BorderSide(
              color: Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Color(0xFF1A1C1E), // Dark neutral
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(
            color: Color(0xFF1A1C1E),
          ),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          const TextTheme(
            titleLarge: TextStyle(
              color: Color(0xFF1A1C1E),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: TextStyle(
              color: Color(0xFF1A1C1E),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(
              color: Color(0xFF1A1C1E),
            ),
            bodyMedium: TextStyle(
              color: Color(0xFF594042),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const GlobalEggyMascot(),
          ],
        );
      },
      home: FutureBuilder<void>(
        future: StudyStateManager.instance.init(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5C77)),
                ),
              ),
            );
          }
          final state = StudyStateManager.instance;
          final bool isLoggedIn = state.isLoggedIn;
          final bool isProfileSetup = state.isProfileSetup;

          if (isLoggedIn) {
            if (isProfileSetup) {
              return const HomeScreen();
            } else {
              return const ProfileSetupScreen();
            }
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}