// lib/screens/join_group_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../widgets/background_circles.dart';
import './qr_scanner_screen.dart'; // <-- IMPORT THE NEW SCREEN

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  bool get _isFormValid {
    return _codeController.text.trim().length == 6 && !_isLoading;
  }

  // --- NEW FUNCTION to open the scanner ---
  Future<void> _scanQRCode() async {
    try {
      // Navigate to the scanner screen and wait for a result
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
      );

      // When it comes back, check if we got a code
      if (result != null && result is String) {
        // Put the scanned code into the text field
        _codeController.text = result;
        // Trigger a state update to enable the button
        setState(() {});

        // --- For better UX, let's automatically try to join ---
        if (_isFormValid) {
          _joinGroupWithCode();
        }
      }
    } catch (e) {
      print('Error scanning code: $e');
    }
  }
  // --- END NEW FUNCTION ---

  Future<void> _joinGroupWithCode() async {
    if (!_isFormValid) {
      // Manually check if the code is not 6 digits, in case of scan error
      if (_codeController.text.trim().length != 6) {
        _showError("รหัสเข้าร่วมต้องมี 6 ตัวอักษร");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in.");
      }

      final db = FirebaseFirestore.instance;
      final enteredCode = _codeController.text.trim().toUpperCase();

      final querySnapshot = await db
          .collection('groups')
          .where('inviteCode', isEqualTo: enteredCode)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("ไม่พบกลุ่มที่ตรงกับรหัสนี้");
      }

      final groupDoc = querySnapshot.docs.first;
      final groupId = groupDoc.id;

      // --- NEW CHECK: Don't let them join a group they are already in ---
      final List<dynamic> currentMembers = groupDoc.data()['members'] ?? [];
      if (currentMembers.contains(user.uid)) {
        throw Exception("คุณเป็นสมาชิกของกลุ่มนี้อยู่แล้ว");
      }
      // --- END NEW CHECK ---

      await db.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayUnion([user.uid]),
      });

      await db.collection('users').doc(user.uid).update({
        'joinedGroups': FieldValue.arrayUnion([groupId]),
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      print("Error joining group: $e");
      setState(() {
        _isLoading = false;
      });
      _showError(
        'เกิดข้อผิดพลาด: ${e.toString().replaceAll("Exception: ", "")}',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'เข้าร่วมกลุ่ม',
          style: TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            color: Color(0xFF374151),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.05),

                  // --- NEW "SCAN" BUTTON ---
                  GestureDetector(
                    onTap: _scanQRCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                      child: const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              color: Color(0xFF2E88F3),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'สแกน QR Code',
                              style: TextStyle(
                                fontFamily: 'NotoLoopedThaiUI',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2E88F3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // --- END NEW BUTTON ---
                  SizedBox(height: screenHeight * 0.03),

                  Text(
                    '— หรือ —',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      color: Colors.grey[500],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.03),

                  // --- This is your existing "Enter Code" box ---
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ป้อนรหัสเข้าร่วม (6 ตัว)',
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.04,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _codeController,
                          onChanged: (_) => setState(() {}),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(6),
                            TextInputFormatter.withFunction(
                              (oldValue, newValue) => newValue.copyWith(
                                text: newValue.text.toUpperCase(),
                                selection: newValue.selection,
                              ),
                            ),
                          ],
                          decoration: InputDecoration(
                            hintText: 'ABC123',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E88F3),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.05),

                  // Join Button
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    CustomButton(
                      text: 'เข้าร่วมกลุ่ม',
                      isEnabled: _isFormValid,
                      onPressed: _joinGroupWithCode,
                    ),
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
    _codeController.dispose();
    super.dispose();
  }
}
