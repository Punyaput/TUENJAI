// lib/screens/terms_screen.dart
import 'package:flutter/material.dart';
import '../utils/legal_text.dart'; // Import the legal text constants
import './legal_display_screen.dart'; // Import the screen that displays markdown

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ข้อกำหนดและนโยบาย'),
      ), // "Terms and Policies"
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.06,
          vertical: 20,
        ),
        children: [
          _buildLegalItem(
            context: context,
            title: 'ข้อกำหนดการใช้งาน', // "Terms of Service"
            icon: Icons.description_outlined,
            markdownContent: kTermsOfServiceText, // Pass ToS text
            screenWidth: screenWidth,
          ),
          const SizedBox(height: 16),
          _buildLegalItem(
            context: context,
            title: 'นโยบายความเป็นส่วนตัว', // "Privacy Policy"
            icon: Icons.privacy_tip_outlined,
            markdownContent: kPrivacyPolicyText, // Pass Privacy Policy text
            screenWidth: screenWidth,
          ),
        ],
      ),
    );
  }

  // Helper widget to create list items
  Widget _buildLegalItem({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String markdownContent,
    required double screenWidth,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          // Navigate to the display screen, passing the title and content
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LegalDisplayScreen(
                title: title,
                markdownContent: markdownContent,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: screenWidth * 0.06,
                color: const Color(0xFF6B7280),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
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
