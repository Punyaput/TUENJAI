// lib/screens/otp_verification_screen.dart

import 'dart:async'; // <-- IMPORT for Timer
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './home_screen.dart';
import './profile_setup_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/logo_widget.dart';
import '../widgets/background_circles.dart';
import '../widgets/otp_input_field.dart';
import './role_selection_screen.dart'; // Make sure this import is here
import 'package:flutter/services.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String countryCode;
  final String verificationId;

  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.countryCode,
    required this.verificationId,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with WidgetsBindingObserver {
  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());

  bool _isResendEnabled = false;
  int _resendCountdown = 60;
  bool _isLoading = false;

  late String _currentVerificationId;
  int? _resendToken;

  Timer? _timer;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // --- Add Binding Observer ---
    WidgetsBinding.instance.addObserver(this);
    // --- Add Keyboard Listener ---
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);

    // Add listeners to focus nodes
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].addListener(_handleFocusChange);
    }
    _currentVerificationId = widget.verificationId;
    _startResendTimer(); // Start the timer
    _listenForAutoFill(); // Listen for the token

    // Request focus on the first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes[0].requestFocus();
    });
  }

  // --- Cancel timer in dispose ---
  @override
  void dispose() {
    // --- Remove Binding Observer ---
    WidgetsBinding.instance.removeObserver(this);
    // --- Remove Keyboard Listener ---
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);

    // Remove focus listeners
    for (int i = 0; i < 6; i++) {
      _focusNodes[i].removeListener(_handleFocusChange);
    }
    // ... (rest of dispose: timer, controllers, focus nodes) ...
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    } else if (state == AppLifecycleState.resumed) {
      HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
    }
  }

  int _currentlyFocusedIndex = 0; // Track focused field

  void _handleFocusChange() {
    for (int i = 0; i < 6; i++) {
      if (_focusNodes[i].hasFocus) {
        setState(() {
          // Use setState to ensure UI updates if needed based on focus
          _currentlyFocusedIndex = i;
        });
        break;
      }
    }
  }

  void _listenForAutoFill() {
    _auth.verifyPhoneNumber(
      phoneNumber: '${widget.countryCode}${widget.phoneNumber}',
      codeSent: (String verificationId, int? resendToken) {
        if (mounted) {
          setState(() {
            _currentVerificationId = verificationId;
            _resendToken = resendToken;
          });
        }
      },
      verificationCompleted: (PhoneAuthCredential credential) {
        if (credential.smsCode != null && credential.smsCode!.length == 6) {
          _setOtpCode(credential.smsCode!);
          _verifyOtp();
        }
      },
      verificationFailed: (e) => print("Listener: Verification failed: $e"),
      codeAutoRetrievalTimeout: (id) =>
          print("Listener: Auto-retrieval timeout."),
      timeout: const Duration(seconds: 5), // Short timeout
    );
  }

  // --- Uses Timer.periodic ---
  void _startResendTimer() {
    _timer?.cancel(); // Cancel any existing timer
    setState(() {
      _isResendEnabled = false;
      _resendCountdown = 60;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        if (_resendCountdown > 0) {
          setState(() {
            _resendCountdown--;
          });
        } else {
          timer.cancel(); // Stop the timer
          setState(() {
            _isResendEnabled = true; // Enable the button
          });
        }
      } else {
        timer.cancel(); // Cancel if widget is disposed
      }
    });
  }

  bool get _isOtpComplete {
    return _otpControllers.every((controller) => controller.text.isNotEmpty);
  }

  String get _otpCode {
    return _otpControllers.map((controller) => controller.text).join();
  }

  void _setOtpCode(String code) {
    if (code.length != 6) return;
    for (int i = 0; i < 6; i++) {
      if (mounted) {
        _otpControllers[i].text = code[i];
      }
    }
    setState(() {});
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isNotEmpty && index == 5) {
      _focusNodes[index].unfocus();
      if (_isOtpComplete) _verifyOtp();
    }
    setState(() {});
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    // We only care about key down events for backspace
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      // Capture the index of the currently focused box *before* any changes
      final int currentIndex = _currentlyFocusedIndex;

      // Check if the currently focused field is empty AND not the first field
      if (currentIndex > 0 && _otpControllers[currentIndex].text.isEmpty) {
        // Determine the index of the field TO CLEAR (the previous one)
        final int previousIndex = currentIndex - 1;

        // Move focus to the previous field
        _focusNodes[previousIndex].requestFocus();

        // Clear the *previous* field's text AFTER a short delay
        // Use the captured 'previousIndex' variable
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            // Ensure widget is still mounted
            // Check if the focus is still where we expect it, just in case,
            // although clearing based on previousIndex should be safe.
            // _otpControllers[previousIndex].clear(); // Directly clear using captured index
            _otpControllers[previousIndex].text =
                ""; // Use assignment to trigger onChanged if needed by any listeners, or just .clear()
          }
        });
        // Return true to indicate we handled the event
        return true;
      } else if (currentIndex == 0 && _otpControllers[0].text.isNotEmpty) {
        // If backspace is pressed on the first field *and it has content*, clear it.
        _otpControllers[0].clear();
        // Return true to indicate we handled the event
        return true;
      }
    }
    // Return false to let other handlers process the event if we didn't handle it
    return false;
  }

  void _resendOtp() async {
    if (!_isResendEnabled) return;
    setState(() {
      _isLoading = true;
      _isResendEnabled = false;
    });

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: '${widget.countryCode}${widget.phoneNumber}',
        forceResendingToken: _resendToken, // Pass the stored token
        verificationCompleted: (PhoneAuthCredential credential) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          if (credential.smsCode != null) _setOtpCode(credential.smsCode!);
          _verifyOtp();
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isResendEnabled = true;
            }); // Re-enable on fail
            _showError('ส่ง OTP อีกครั้งไม่สำเร็จ: ${e.message}');
            // DO NOT restart timer here, just re-enable the button
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _currentVerificationId = verificationId;
              _resendToken = resendToken; // Store new token
              _isLoading = false;
              for (var controller in _otpControllers) {
                controller.clear();
              }
            });
            _focusNodes[0].requestFocus();
            _startResendTimer(); // <-- This correctly restarts the timer
            _showError('ส่งรหัส OTP ใหม่แล้ว', isError: false);
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isResendEnabled = true;
            });
          }
        },
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isResendEnabled = true;
        });
        _showError('เกิดข้อผิดพลาด: $e');
      }
    }
  }

  void _verifyOtp() async {
    if (!_isOtpComplete || _isLoading) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: _otpCode,
      );
      await _auth.signInWithCredential(credential);
      _navigateToNextScreenAfterLogin(); // Handle navigation
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError(
        e.code == 'invalid-verification-code'
            ? 'รหัส OTP ไม่ถูกต้อง กรุณาลองใหม่'
            : 'เกิดข้อผิดพลาด: ${e.message}',
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('เกิดข้อผิดพลาด: $e');
    }
  }

  void _showError(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  void _navigateToNextScreenAfterLogin() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
      });
      _showError("ไม่พบผู้ใช้งานหลังจากการยืนยัน");
      return;
    }

    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(user.uid).get();
      if (!mounted) return;

      if (userDoc.exists) {
        // OLD USER. Check if they have a role.
        final data = userDoc.data();
        if (data != null && data.containsKey('role')) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        } else {
          // User exists but didn't finish setup. Send to role selection.
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const RoleSelectionScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        // NEW USER
        await db.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phoneNumber': '${widget.countryCode}${widget.phoneNumber}',
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return; // stop if widget is disposed
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const ProfileSetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError("เกิดข้อผิดพลาดในการดึงข้อมูลผู้ใช้: $e");
      }
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
            Positioned.fill(
              child: Stack(
                children: [
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
                ],
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: screenHeight * 0.02),
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
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.02,
                      ),
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
                            const TextSpan(
                              text:
                                  'กรุณากรอกรหัส OTP 6 หลัก\nที่ส่งไปยังหมายเลข ',
                            ),
                            TextSpan(
                              text:
                                  '${widget.countryCode} ${widget.phoneNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2E88F3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.04),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
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
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(6, (index) {
                          return OtpInputField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            onChanged: (value) => _onOtpChanged(index, value),
                            // No index or allFocusNodes needed here now
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.03),
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
                        InkWell(
                          onTap: _resendOtp, // Call the updated function
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

                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      CustomButton(
                        text: 'ยืนยัน',
                        isEnabled:
                            _isOtpComplete && !_isLoading, // Disable if loading
                        onPressed: _verifyOtp,
                      ),
                    SizedBox(height: screenHeight * 0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
