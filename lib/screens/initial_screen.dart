import 'package:flutter/material.dart';
import '../widgets/custom_button.dart';
import '../widgets/logo_widget.dart';
import '../widgets/background_circles.dart';
import './login_screen.dart';

class InitialScreen extends StatelessWidget {
  const InitialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            // Background container fills the screen
            Positioned.fill(
              child: Stack(
                children: [
                  // Top circles
                  Positioned(
                    top: -screenHeight * 0.08,
                    left: -screenWidth * 0.34,
                    child: const TopBackgroundCircles(),
                  ),
                  // Bottom circles
                  Positioned(
                    bottom: -screenHeight * 0.1,
                    left: -screenWidth * 0.2,
                    child: const BottomBackgroundCircles(),
                  ),
                ],
              ),
            ),

            // Main content
            Column(
              children: [
                SizedBox(height: screenHeight * 0.15),

                // Logo and app name
                const LogoWidget(),
                SizedBox(height: screenHeight * 0.03),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'TUEN',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: screenWidth * 0.13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E88F3),
                        ),
                      ),
                      TextSpan(
                        text: 'JAI',
                        style: TextStyle(
                          fontFamily: 'Raleway',
                          fontSize: screenWidth * 0.13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF7ED6A8),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: screenHeight * 0.02),

                // Description text
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.18),
                  child: Text(
                    'แอปพลิเคชันช่วยเหลือผู้ดูแล เพื่อช่วยเหลือผู้ป่วย Alzheimer',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.046,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF202020),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                SizedBox(height: screenHeight * 0.09),

                // Start button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                  child: CustomButton(
                    text: 'เริ่มต้นใช้งาน',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                  ),
                ),

                SizedBox(height: screenHeight * 0.05), // bottom spacing
              ],
            ),
          ],
        ),
      ),
    );
  }
}
