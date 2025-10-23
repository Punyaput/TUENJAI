// lib/screens/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Needed for Firestore delete
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import './profile_settings_screen.dart';
import './login_screen.dart';
import './groups_screen.dart';
import './home_screen.dart';
import './terms_screen.dart';
import './help_screen.dart';
import '../widgets/custom_fade_route.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 2; // Settings tab is selected
  bool _isDeleting = false; // Loading state for deletion

  void _onItemTapped(int index) {
    // ... (Navigation logic remains unchanged) ...
    if (index == _selectedIndex) return;
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        FadeRoute(child: const GroupsScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(context, FadeRoute(child: const HomeScreen()));
    }
  }

  void _showLogoutDialog() {
    // ... (Logout dialog remains unchanged) ...
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ออกจากระบบ',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'คุณต้องการออกจากระบบหรือไม่?',
            style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                try {
                  await FirebaseAuth.instance.signOut();
                  if (mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  print("Error logging out: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('เกิดข้อผิดพลาดในการออกจากระบบ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'ออกจากระบบ',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- NEW: Delete Account Confirmation Dialog ---
  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      barrierDismissible: !_isDeleting, // Prevent dismissing while loading
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ยืนยันการลบบัญชี',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบบัญชีนี้อย่างถาวร? ข้อมูลทั้งหมดของคุณจะถูกลบและไม่สามารถกู้คืนได้',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              color: Colors.grey[700],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isDeleting
                  ? null
                  : () => Navigator.of(
                      dialogContext,
                    ).pop(), // Disable during delete
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            // Show loading indicator or delete button
            _isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed:
                        _handleAccountDeletion, // Call the deletion logic
                    child: const Text(
                      'ลบบัญชี',
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        );
      },
    ).then((_) {
      // Reset loading state if dialog is dismissed externally
      if (mounted && _isDeleting) {
        setState(() {
          _isDeleting = false;
        });
      }
    });
  }
  // --- END NEW DIALOG ---

  // --- NEW: Handle Account Deletion Logic ---
  Future<void> _handleAccountDeletion() async {
    if (!mounted) return; // Check if widget is still active
    setState(() {
      _isDeleting = true;
    }); // Show loading in dialog

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError("ไม่พบผู้ใช้งาน กรุณาเข้าสู่ระบบใหม่");
      if (mounted) Navigator.of(context).pop(); // Close the confirmation dialog
      _logout(); // Force logout
      return;
    }

    final userId = user.uid; // Get ID before deleting auth user

    try {
      // 1. Delete Firestore Data FIRST
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      print("Firestore user document deleted for $userId");

      // TODO (Advanced): Remove user from groups' member lists

      // 2. Delete Firebase Auth User
      await user.delete();
      print("Firebase Auth user deleted for $userId");

      // 3. Navigate to Login Screen
      if (mounted) {
        // Close the confirmation dialog first if it's still somehow open
        // Navigator.of(context).pop(); // Might cause issues if called twice

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบบัญชีเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
        // Navigate home, removing history
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      print("Error deleting account: ${e.code} - ${e.message}");
      if (mounted) {
        Navigator.of(context).pop(); // Close confirmation dialog on error
        setState(() {
          _isDeleting = false;
        }); // Hide loading
        if (e.code == 'requires-recent-login') {
          _showError(
            'การดำเนินการนี้ต้องมีการยืนยันตัวตนใหม่ กรุณาออกจากระบบและเข้าสู่ระบบอีกครั้งก่อนลองลบบัญชี',
          );
          // TODO: Implement re-authentication flow for a better UX
        } else {
          _showError('เกิดข้อผิดพลาดในการลบบัญชี: ${e.message}');
        }
      }
    } catch (e) {
      print("Error deleting Firestore data or other error: $e");
      if (mounted) {
        Navigator.of(context).pop(); // Close confirmation dialog
        setState(() {
          _isDeleting = false;
        }); // Hide loading
        _showError('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  // Helper to show error messages
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }
  // --- END NEW LOGIC ---

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        // SafeArea handles notches/system bars
        child: Stack(
          children: [
            // Background circles
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),

            // --- RESTRUCTURED CONTENT ---
            // Main Column takes all available vertical space
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Padding
                Padding(
                  padding: EdgeInsets.only(
                    left: screenWidth * 0.06,
                    right: screenWidth * 0.06,
                    top: screenHeight * 0.04, // Keep top padding
                  ),
                  child: Text(
                    'ตั้งค่า',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E88F3),
                    ),
                  ),
                ),
                SizedBox(height: screenHeight * 0.04),

                // Expanded ListView fills remaining space
                Expanded(
                  child: ListView(
                    // Add horizontal padding here
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.06,
                    ),
                    children: [
                      _buildSettingsItem(
                        icon: Icons.person_outline,
                        title: 'ตั้งค่าโปรไฟล์',
                        subtitle: 'แก้ไขข้อมูลส่วนตัวของคุณ',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfileSettingsScreen(),
                            ),
                          );
                        },
                        screenWidth: screenWidth,
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        icon: Icons.description_outlined,
                        title: 'ข้อกำหนดการใช้งาน',
                        subtitle: 'อ่านข้อกำหนดและเงื่อนไข',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TermsScreen(),
                            ),
                          );
                        },
                        screenWidth: screenWidth,
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        icon: Icons.help_outline,
                        title: 'ช่วยเหลือ',
                        subtitle: 'คำถามที่พบบ่อยและการสนับสนุน',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HelpScreen(),
                            ),
                          );
                        },
                        screenWidth: screenWidth,
                      ),
                      SizedBox(height: screenHeight * 0.05),
                      _buildSettingsItem(
                        icon: Icons.logout,
                        title: 'ออกจากระบบ',
                        subtitle: 'ออกจากบัญชีผู้ใช้ปัจจุบัน',
                        onTap: _showLogoutDialog,
                        screenWidth: screenWidth,
                        isDestructive: true,
                      ),
                      const SizedBox(height: 16),
                      _buildSettingsItem(
                        icon: Icons.delete_forever_outlined,
                        title: 'ลบบัญชี',
                        subtitle: 'ลบบัญชีและข้อมูลทั้งหมดของคุณอย่างถาวร',
                        onTap: _showDeleteAccountDialog,
                        screenWidth: screenWidth,
                        isDestructive: true,
                      ),
                      const SizedBox(
                        height: 20,
                      ), // Add some padding at the bottom of the list
                    ],
                  ),
                ),
                // --- NO bottom padding needed here ---
              ],
            ),
            // --- END RESTRUCTURE ---
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
    // Ensure navigation happens only if the widget is still mounted
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, // Remove all routes below
      );
    }
  }

  // --- UPDATED: Use consistent red colors ---
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required double screenWidth,
    bool isDestructive = false,
  }) {
    final Color iconColor = isDestructive
        ? Colors.red.shade600
        : const Color(0xFF2E88F3); // Darker Red or Blue
    final Color titleColor = isDestructive
        ? Colors.red.shade700
        : const Color(0xFF374151); // Darkest Red or Default Text
    final Color iconBackgroundColor = iconColor.withOpacity(0.1);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: screenWidth * 0.12,
                height: screenWidth * 0.12,
                decoration: BoxDecoration(
                  color: iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: screenWidth * 0.06, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: screenWidth * 0.035,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 24, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
