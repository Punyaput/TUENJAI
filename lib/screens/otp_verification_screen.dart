import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/custom_button.dart';
import '../widgets/logo_widget.dart';
import '../widgets/background_circles.dart';
import '../widgets/otp_input_field.dart';
import './profile_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _otpControllers = 
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = 
      List.generate(6, (index) => FocusNode());
  
  bool _isResendEnabled = false;
  int _resendCountdown = 60;
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
        _startResendTimer();
      } else if (mounted) {
        setState(() {
          _isResendEnabled = true;
        });
      }
    });
  }

  bool get _isOtpComplete {
    return _otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onBackspace(int index) {
    if (index > 0) {
      _otpControllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _resendOtp() {
    if (_isResendEnabled) {
      setState(() {
        _isResendEnabled = false;
        _resendCountdown = 60;
      });
      _startResendTimer();
      
      // Clear all OTP fields
      for (var controller in _otpControllers) {
        controller.clear();
      }
      _focusNodes[0].requestFocus();
      
      print('Resending OTP to ${widget.countryCode}${widget.phoneNumber}');
    }
  }

  void _verifyOtp() {
    if (_isOtpComplete) {
      print('Verifying OTP: $_otpCode');
      // Navigate to profile setup for first-time users
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileSetupScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: false,
      body: SafeArea(   // ✅ wrapped entire body
        child: Stack(
          children: [
            // Background circles
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
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.1),
                  const LogoWidget(),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Verify',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: screenWidth * 0.11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF7ED6A8),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),

                  // Description text
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: screenWidth * 0.04,
                          color: const Color(0xFF6B7280),
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'กรุณากรอกรหัส OTP ที่ส่งไปยัง\n'),
                          TextSpan(
                            text: '${widget.countryCode} ${widget.phoneNumber}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2E88F3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),

                  // OTP Input Fields
                  Container(
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(6, (index) {
                            return OtpInputField(
                              controller: _otpControllers[index],
                              focusNode: _focusNodes[index],
                              onChanged: (value) => _onOtpChanged(index, value),
                              onBackspace: () => _onBackspace(index),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // Resend OTP section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'ไม่ได้รับรหัส OTP? ',
                        style: TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: screenWidth * 0.035,
                          color: const Color(0xFF6B7280),
                        ),
                      ),
                      GestureDetector(
                        onTap: _resendOtp,
                        child: Text(
                          _isResendEnabled
                              ? 'ส่งใหม่'
                              : 'ส่งใหม่ใน $_resendCountdown วินาที',
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.035,
                            color: _isResendEnabled
                                ? const Color(0xFF2E88F3)
                                : const Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w600,
                            decoration: _isResendEnabled
                                ? TextDecoration.underline
                                : null,
                            decorationColor: const Color(0xFF2E88F3),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenHeight * 0.05),

                  CustomButton(
                    text: 'ยืนยัน',
                    isEnabled: _isOtpComplete,
                    onPressed: _verifyOtp,
                  ),

                  SizedBox(height: screenHeight * 0.2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}