// lib/screens/join_group_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/custom_button.dart';
import '../widgets/background_circles.dart';
import './qr_scanner_screen.dart';

class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  bool get _isFormValid {
    // --- UPDATED: Check for 8 characters ---
    return _codeController.text.trim().length == 8 && !_isLoading;
  }

  Future<void> _scanQRCode() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QrScannerScreen()),
      );
      if (result != null && result is String) {
        _codeController.text = result;
        setState(() {});
        if (_codeController.text.trim().length == 8) {
          // Check for 8
          _joinGroupWithCode(); // Auto-submit if 8 chars
        }
      }
    } catch (e) {
      // Ignore scan errors
    }
  }

  // --- UPDATED: This function now SENDS A REQUEST ---
  Future<void> _joinGroupWithCode() async {
    if (_codeController.text.trim().length != 8) {
      _showError("รหัสเข้าร่วมต้องมี 8 ตัวอักษร");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final db = FirebaseFirestore.instance;
      final enteredCode = _codeController.text
          .trim(); // No need to uppercase, codes are case-sensitive

      // 1. Find group with this code
      final querySnapshot = await db
          .collection('groups')
          .where('inviteCode', isEqualTo: enteredCode) // Use exact code
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        throw Exception("ไม่พบกลุ่มที่ตรงกับรหัสนี้");
      }

      final groupDoc = querySnapshot.docs.first;
      final groupId = groupDoc.id;
      final groupData = groupDoc.data();

      // 2. Check if already a member or pending
      final List<dynamic> currentMembers = groupData['members'] ?? [];
      if (currentMembers.contains(user.uid)) {
        throw Exception("คุณเป็นสมาชิกของกลุ่มนี้อยู่แล้ว");
      }
      final List<dynamic> pendingRequests = groupData['pendingRequests'] ?? [];
      if (pendingRequests.contains(user.uid)) {
        throw Exception("คุณได้ส่งคำขอเข้าร่วมกลุ่มนี้ไปแล้ว");
      }

      // --- 3. THIS IS THE CHANGE ---
      // Add user to the 'pendingRequests' list instead of 'members'
      await db.collection('groups').doc(groupId).update({
        'pendingRequests': FieldValue.arrayUnion([user.uid]),
      });

      // 4. Do NOT add group to user's 'joinedGroups' yet.

      if (mounted) {
        // 5. Show success and pop
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ส่งคำขอเข้าร่วมกลุ่มแล้ว',
              style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
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
      appBar: AppBar(title: const Text('เข้าร่วมกลุ่ม')),
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
                  GestureDetector(
                    /* ... (Scan QR Button is unchanged) ... */
                    onTap: _scanQRCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
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
                  SizedBox(height: screenHeight * 0.03),
                  Text(
                    '— หรือ —',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      color: Colors.grey[500],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),

                  Container(
                    // --- Enter Code Box ---
                    padding: const EdgeInsets.all(24),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ป้อนรหัสเข้าร่วม (8 ตัว)', // <-- Updated text
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
                          maxLength: 8, // <-- Updated length
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(
                              8,
                            ), // <-- Updated length
                            // Allow all chars, or just alphanumeric?
                            // FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                          decoration: InputDecoration(
                            counterText: '', // Hide counter
                            hintText: 'ABC123XY', // <-- Updated hint
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

                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    CustomButton(
                      text: 'ส่งคำขอเข้าร่วม', // <-- Updated text
                      isEnabled: _isFormValid,
                      onPressed: _joinGroupWithCode,
                    ),

                  SizedBox(height: screenHeight * 0.39),
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
