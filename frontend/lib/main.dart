import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'widgets/global_eggy.dart';
import 'services/study_state_manager.dart';

void main() {
  debugPrint("APP_START: main() called");
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint("APP_START: WidgetsFlutterBinding initialized");
  runApp(const StudyPlannerApp());
}

class StudyPlannerApp extends StatefulWidget {
  const StudyPlannerApp({super.key});

  @override
  State<StudyPlannerApp> createState() => _StudyPlannerAppState();
}

class _StudyPlannerAppState extends State<StudyPlannerApp> {
  late final Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    debugPrint("APP_START: StudyPlannerApp initState() called");
    _initFuture = StudyStateManager.instance.init();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("APP_START: StudyPlannerApp build() called");
    return MaterialApp(
      scrollBehavior: const GlobalScrollBehavior(),
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
        debugPrint("APP_START: MaterialApp builder called, child is null = ${child == null}");
        return child ?? const SizedBox.shrink();
      },
      home: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          debugPrint("APP_START: FutureBuilder builder snapshot.connectionState = ${snapshot.connectionState}, hasError = ${snapshot.hasError}");
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF5C77)),
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          "Initialization Error",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            try {
                              await Hive.deleteFromDisk();
                            } catch (_) {}
                            // Simple suggestion to restart app
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5C77),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text("Clear App Data & Reset Cache"),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          snapshot.stackTrace?.toString() ?? "",
                          style: const TextStyle(
                            fontSize: 10,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
          final state = StudyStateManager.instance;
          final bool isLoggedIn = state.isLoggedIn;
          final bool isProfileSetup = state.isProfileSetup;
          debugPrint("APP_START: Route selection: isLoggedIn = $isLoggedIn, isProfileSetup = $isProfileSetup");

          if (isLoggedIn) {
            if (isProfileSetup) {
              debugPrint("APP_START: Returning HomeScreen");
              return const HomeScreen();
            } else {
              debugPrint("APP_START: Returning ProfileSetupScreen");
              return const ProfileSetupScreen();
            }
          } else {
            debugPrint("APP_START: Returning LoginScreen");
            return const LoginScreen();
          }
        },
      ),
    );
  }
}

class GlobalScrollBehavior extends ScrollBehavior {
  const GlobalScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        );
      case TargetPlatform.android:
      default:
        return const ClampingScrollPhysics(
          parent: RangeMaintainingScrollPhysics(),
        );
    }
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return child;
      case TargetPlatform.android:
      default:
        return GlowingOverscrollIndicator(
          axisDirection: details.direction,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          child: child,
        );
    }
  }
}