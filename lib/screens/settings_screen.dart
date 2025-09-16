import 'package:flutter/material.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import './profile_settings_screen.dart';
import './login_screen.dart';
import './groups_screen.dart';
import './home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _selectedIndex = 2; // Settings tab selected

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return; // already on this tab

    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GroupsScreen()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 2) {
      // already on Settings, do nothing
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              },
              child: const Text(
                'ออกจากระบบ',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            // Bottom background circles only
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.only(
                left: screenWidth * 0.06,
                right: screenWidth * 0.06,
                top: screenHeight * 0.02,
                bottom: 100, // Space for bottom navigation
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'ตั้งค่า',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E88F3),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Settings options
                  Expanded(
                    child: ListView(
                      children: [
                        _buildSettingsItem(
                          icon: Icons.person,
                          title: 'ตั้งค่าโปรไฟล์',
                          subtitle: 'แก้ไขข้อมูลส่วนตัว',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileSettingsScreen(),
                              ),
                            );
                          },
                          screenWidth: screenWidth,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildSettingsItem(
                          icon: Icons.description,
                          title: 'ข้อกำหนดการใช้งาน',
                          subtitle: 'อ่านข้อกำหนดและเงื่อนไข',
                          onTap: () {
                            print('Terms of Service tapped');
                            // TODO: Navigate to Terms of Service screen
                          },
                          screenWidth: screenWidth,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        _buildSettingsItem(
                          icon: Icons.help,
                          title: 'ช่วยเหลือ',
                          subtitle: 'คำถามที่พบบ่อยและการสนับสนุน',
                          onTap: () {
                            print('Help tapped');
                            // TODO: Navigate to Help screen
                          },
                          screenWidth: screenWidth,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Logout button
                        _buildSettingsItem(
                          icon: Icons.logout,
                          title: 'ออกจากระบบ',
                          subtitle: 'ออกจากบัญชีผู้ใช้',
                          onTap: _showLogoutDialog,
                          screenWidth: screenWidth,
                          isDestructive: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required double screenWidth,
    bool isDestructive = false,
  }) {
    final iconColor = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF2E88F3);
    final titleColor = isDestructive ? const Color(0xFFEF4444) : const Color(0xFF374151);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: screenWidth * 0.12,
                  height: screenWidth * 0.12,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: screenWidth * 0.06,
                    color: iconColor,
                  ),
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
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}