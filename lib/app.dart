// lib/app.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import your screens needed by AuthWrapper
import 'screens/initial_screen.dart';
import 'screens/home_screen.dart';
// Add any other imports TuenJaiApp might need (like themes)

class TuenJaiApp extends StatelessWidget {
  const TuenJaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TuenJai', // Consider adding "(Dev)" here based on flavor later
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
      home: const AuthWrapper(),
      debugShowCheckedModeBanner:
          false, // Keep false for prod, maybe true for dev
    );
  }
}

// AuthWrapper remains the same
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen(); // User logged IN
        } else {
          return const InitialScreen(); // User logged OUT
        }
      },
    );
  }
}
