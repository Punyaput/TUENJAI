// lib/screens/role_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './home_screen.dart';
import '../widgets/logo_widget.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  // This function is where the magic happens
  Future<void> _selectRole(String role) async {
    setState(() {
      _isLoading = true; // Show a loading circle
    });

    try {
      // 1. Get the currently logged-in user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // This should never happen, but it's good to check
        throw Exception('No user logged in');
      }

      // 2. Get the database
      final db = FirebaseFirestore.instance;

      // 3. Save the user's chosen role to their profile in Firestore
      //    We are 'updating' the user document we created earlier.
      await db.collection('users').doc(user.uid).update({
        'role': role, // This is the all-important field!
        'createdAt':
            FieldValue.serverTimestamp(), // Good to know when they joined
      });

      // 4. Role is saved! Send them to the Home Screen.
      //    We use pushAndRemoveUntil to clear all previous screens (login, otp, etc.)
      //    so the user can't press "back" and go to them.
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
          (route) => false, // This line removes all routes behind it
        );
      }
    } catch (e) {
      // If something goes wrong, stop loading and show an error
      setState(() {
        _isLoading = false;
      });
      // You could show a SnackBar error here
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Show the logo
              const LogoWidget(),
              SizedBox(height: screenHeight * 0.05),

              // Header text
              Text(
                'เลือกบทบาทของคุณ', // "Choose your role"
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: screenWidth * 0.07,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF374151),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'บทบาทนี้จะกำหนดวิธีการใช้งานแอปของคุณ', // "This role will define how you use the app"
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: screenWidth * 0.04,
                  color: const Color(0xFF6B7280),
                ),
              ),
              SizedBox(height: screenHeight * 0.08),

              // If loading, show a circle. Otherwise, show the buttons.
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else ...[
                // --- Caretaker Button ---
                _buildRoleButton(
                  context: context,
                  icon: Icons.admin_panel_settings,
                  title: 'ฉันเป็นผู้ดูแล', // "I am a Caretaker"
                  subtitle:
                      'สำหรับสร้างและจัดการกลุ่มและงานต่างๆ', // "For creating and managing groups and tasks"
                  color: const Color(0xFF2E88F3), // Your action blue
                  onTap: () => _selectRole('caretaker'),
                ),
                SizedBox(height: screenHeight * 0.03),

                // --- Care Receiver Button ---
                _buildRoleButton(
                  context: context,
                  icon: Icons.person,
                  title: 'ฉันเป็นผู้รับการดูแล', // "I am a Care Receiver"
                  subtitle:
                      'สำหรับดูและทำเครื่องหมายงานที่ได้รับ', // "For viewing and checking off assigned tasks"
                  color: const Color(0xFF7ED6A8), // Your action green
                  onTap: () => _selectRole('carereceiver'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // A helper widget to make the buttons look good
  Widget _buildRoleButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
