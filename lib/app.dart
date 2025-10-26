// lib/app.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import your screens needed by AuthWrapper
import 'screens/initial_screen.dart';
import 'screens/home_screen.dart';
import 'screens/role_selection_screen.dart';
import 'screens/profile_setup_screen.dart';
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
      builder: (context, authSnapshot) {
        // 1. Check Auth Connection State
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. Check if User is Logged In
        if (authSnapshot.hasData && authSnapshot.data != null) {
          // User is logged IN - Now check Firestore for profile/role
          final user = authSnapshot.data!;

          return FutureBuilder<DocumentSnapshot>(
            // Fetch the user's document from Firestore
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userDocSnapshot) {
              // Check Firestore Connection State
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ), // Show loading while fetching doc
                );
              }

              // Check if Firestore document exists and has data
              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData =
                    userDocSnapshot.data!.data() as Map<String, dynamic>?;

                // Check for USERNAME first (profile setup completion)
                if (userData == null ||
                    !(userData.containsKey('username')) ||
                    (userData['username'] as String? ?? '').isEmpty) {
                  // Edge Case: User exists but profile setup wasn't fully completed
                  // (Should ideally not happen if ProfileSetupScreen logic is robust, but good to handle)
                  // print(
                  //   "AuthWrapper: User ${user.uid} missing username, navigating to ProfileSetupScreen.",
                  // );
                  return const ProfileSetupScreen();
                }
                // Check for ROLE
                else if (userData.containsKey('role') &&
                    (userData['role'] as String? ?? '').isNotEmpty) {
                  // User has a role - Go to HomeScreen
                  // print(
                  //   "AuthWrapper: User ${user.uid} has role, navigating to HomeScreen.",
                  // );
                  return const HomeScreen();
                } else {
                  // User exists and has username, but NO role - Go to RoleSelectionScreen
                  // print(
                  //   "AuthWrapper: User ${user.uid} missing role, navigating to RoleSelectionScreen.",
                  // );
                  return const RoleSelectionScreen();
                }
              } else {
                // User is authenticated, but Firestore document doesn't exist yet
                // This might happen briefly during the very first sign-in before ProfileSetupScreen creates it.
                // Sending to ProfileSetupScreen is safer here.
                // print(
                //   "AuthWrapper: User ${user.uid} Firestore doc doesn't exist, navigating to ProfileSetupScreen.",
                // );
                // Alternatively, could show an error or try creating a basic doc here,
                // but ProfileSetupScreen handles doc creation/update.
                return const ProfileSetupScreen();
              }
            },
          );
        } else {
          // User is logged OUT - Go to InitialScreen
          // print(
          //   "AuthWrapper: No authenticated user, navigating to InitialScreen.",
          // );
          return const InitialScreen();
        }
      },
    );
  }
}
