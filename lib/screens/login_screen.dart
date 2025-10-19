// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../widgets/custom_button.dart';
import '../widgets/logo_widget.dart';
import '../widgets/background_circles.dart';
import './otp_verification_screen.dart';
import './home_screen.dart';
import './profile_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _acceptedTerms = false;
  String _selectedCountryCode = '+66';
  String _selectedCountryFlag = '🇹🇭';
  bool _isLoading = false; // <-- Add loading state

  final List<Map<String, String>> _countries = [
    {'code': '+66', 'flag': '🇹🇭', 'name': 'Thailand'},
    // ... other countries
  ];
  
  // --- We need an instance of Firebase Auth ---
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool get _isFormValid {
    return _phoneController.text.isNotEmpty && _acceptedTerms && !_isLoading;
  }

  void _showCountryPicker() {
    // ... (Your existing _showCountryPicker - no change)
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'เลือกประเทศ',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _countries.length,
                  itemBuilder: (context, index) {
                    final country = _countries[index];
                    return ListTile(
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        country['name']!,
                        style: const TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: 16,
                        ),
                      ),
                      trailing: Text(
                        country['code']!,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedCountryCode = country['code']!;
                          _selectedCountryFlag = country['flag']!;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- NEW FUNCTION TO SEND OTP ---
  void _sendOtp() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
    });
    
    // --- ADDED TRY...CATCH BLOCK ---
    try {
      String phoneNumber = _phoneController.text.trim();
      if (_selectedCountryCode == '+66' && phoneNumber.startsWith('0')) {
        phoneNumber = phoneNumber.substring(1);
      }
      final fullPhoneNumber = '$_selectedCountryCode$phoneNumber';
      await _auth.verifyPhoneNumber(
        phoneNumber: fullPhoneNumber,
        
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _navigateToNextScreenAfterLogin();
        },
        
        verificationFailed: (FirebaseAuthException e) {
          print('Verification Failed: ${e.message}');
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('ส่ง OTP ไม่สำเร็จ: ${e.message}'),
                  backgroundColor: Colors.red),
            );
          }
        },
        
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  phoneNumber: _phoneController.text,
                  countryCode: _selectedCountryCode,
                  verificationId: verificationId,
                ),
              ),
            );
          }
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Code auto retrieval timeout');
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      // This is the safety net
      print('An unexpected error occurred: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
    // --- END TRY...CATCH BLOCK ---
  }

  // Helper function to check where to go after auto-login
  void _navigateToNextScreenAfterLogin() async {
    final user = _auth.currentUser;
    if (user == null) return; // Should not happen

    final db = FirebaseFirestore.instance;
    final userDoc = await db.collection('users').doc(user.uid).get();

    if (userDoc.exists) {
      // OLD USER
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } else {
      // NEW USER
      await db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'phoneNumber': user.phoneNumber,
      });
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
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
      body: SafeArea(
        child: Stack(
          children: [
            // ... (Your background circles - no change)
            Positioned(
              top: -screenHeight * 0.08,
              left: -screenWidth * 0.34,
              child: const TopBackgroundCircles(),
            ),
            Positioned(
              bottom: -screenHeight * 0.1,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),

            // Scrollable main content
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: Column(
                children: [
                  // ... (Your Logo, Title, and Phone Input - no change)
                  SizedBox(height: screenHeight * 0.1),
                  const LogoWidget(),
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    'Login',
                    style: TextStyle(
                      fontFamily: 'Raleway',
                      fontSize: screenWidth * 0.11,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E88F3),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'หมายเลขโทรศัพท์',
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: _showCountryPicker,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: const Color(0xFFD1D5DB)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_selectedCountryFlag,
                                        style:
                                            const TextStyle(fontSize: 20)),
                                    const SizedBox(width: 4),
                                    Text(_selectedCountryCode,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500)),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.keyboard_arrow_down,
                                      size: 20,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(10),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText: 'เช่น 0812345678',
                                  hintStyle: TextStyle(
                                      fontFamily: 'NotoLoopedThaiUI',
                                      color: Colors.grey[400]),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFFD1D5DB)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF2E88F3),
                                        width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),
                  
                  // ... (Your Terms Checkbox - no change)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _acceptedTerms = !_acceptedTerms),
                        child: Container(
                          width: 20,
                          height: 20,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: _acceptedTerms
                                ? const Color(0xFF2E88F3)
                                : Colors.white,
                            border: Border.all(
                                color: _acceptedTerms
                                    ? const Color(0xFF2E88F3)
                                    : const Color(0xFFD1D5DB),
                                width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: _acceptedTerms
                              ? const Icon(Icons.check,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontFamily: 'NotoLoopedThaiUI',
                                fontSize: screenWidth * 0.035,
                                color: const Color(0xFF374151),
                                height: 1.5),
                            children: [
                              const TextSpan(text: 'ฉันยอมรับ '),
                              TextSpan(
                                text: 'ข้อกำหนดการใช้งาน',
                                style: TextStyle(
                                    color: const Color(0xFF2E88F3),
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        const Color(0xFF2E88F3)),
                              ),
                              const TextSpan(text: ' และ '),
                              TextSpan(
                                text: 'นโยบายความเป็นส่วนตัว',
                                style: TextStyle(
                                    color: const Color(0xFF2E88F3),
                                    decoration: TextDecoration.underline,
                                    decorationColor:
                                        const Color(0xFF2E88F3)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: screenHeight * 0.05),

                  // --- UPDATED CustomButton ---
                  // It now shows a loading indicator and calls _sendOtp
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    CustomButton(
                      text: 'ดำเนินการต่อ',
                      isEnabled: _isFormValid,
                      onPressed: _sendOtp, // <-- CHANGED
                    ),

                  SizedBox(height: screenHeight * 0.2), // bottom padding
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
    _phoneController.dispose();
    super.dispose();
  }
}