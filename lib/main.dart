// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <-- Import Auth
import 'package:intl/date_symbol_data_local.dart';
// Import your screens
import 'screens/initial_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart'; // Needed for logged-out state

// Use this if you have firebase_options.dart from flutterfire configure
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Choose ONE method)
  await Firebase.initializeApp(); // Native method
  // OR:
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform, // FlutterFire CLI method
  // );

  await initializeDateFormatting('th', null);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TuenJaiApp());
}

class TuenJaiApp extends StatelessWidget {
  const TuenJaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuenJai',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E88F3)),
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        fontFamily: 'NotoLoopedThaiUI',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF9FAFB),
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF374151)),
          titleTextStyle: TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            color: Color(0xFF374151),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      // --- Use AuthWrapper instead of SplashScreen directly ---
      home: const AuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- NEW Wrapper Widget ---
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // StreamBuilder listens to authentication state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. Check connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while checking auth state
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Check if user data exists in the snapshot
        if (snapshot.hasData && snapshot.data != null) {
          // User is logged IN - Go to HomeScreen
          print(
            "AuthWrapper: User is logged in (${snapshot.data!.uid}). Navigating to HomeScreen.",
          ); // Debug log
          return const HomeScreen();
        } else {
          // User is logged OUT - Go to InitialScreen (which leads to LoginScreen)
          print(
            "AuthWrapper: User is logged out. Navigating to InitialScreen.",
          ); // Debug log
          return const InitialScreen();
        }
      },
    );
  }
}
