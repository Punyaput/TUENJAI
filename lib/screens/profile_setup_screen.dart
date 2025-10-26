// lib/screens/profile_setup_screen.dart

import 'dart:io'; // Import for File
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart'; // Import Storage
import 'package:image_picker/image_picker.dart'; // Import Image Picker
import './role_selection_screen.dart';
import '../widgets/custom_button.dart';
import '../widgets/background_circles.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;

  bool get _isFormValid {
    return _usernameController.text.trim().isNotEmpty && !_isLoading;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการเลือกรูปภาพ: $e");
    }
  }

  void _selectProfileImage() {
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
                'เลือกรูปโปรไฟล์',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageOption(
                    icon: Icons.camera_alt,
                    label: 'กล้อง',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'แกลเลอรี่',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2E88F3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(icon, size: 30, color: const Color(0xFF2E88F3)),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 14,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _uploadImageToStorage(XFile imageFile, String userId) async {
    try {
      final String fileName =
          'profile_pics/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );
      final UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      _showError("เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e");
      return null;
    }
  }

  void _completeSetup() async {
    if (!_isFormValid) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final db = FirebaseFirestore.instance;
      String? profilePicUrl;

      if (_imageFile != null) {
        profilePicUrl = await _uploadImageToStorage(_imageFile!, user.uid);
        if (profilePicUrl == null) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      await db.collection('users').doc(user.uid).update({
        'username': _usernameController.text.trim(),
        'description': _descriptionController.text.trim(),
        if (profilePicUrl != null) 'profilePicUrl': profilePicUrl,
        'profileLastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('เกิดข้อผิดพลาดในการบันทึกโปรไฟล์: $e');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: false, // Use true with SingleChildScrollView
      body: SafeArea(
        child: Stack(
          children: [
            // Background circles will now stay positioned relative to the Stack
            Positioned(
              bottom: -screenWidth * 0.18,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),

            // LayoutBuilder provides the available screen height
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  // Padding is now inside the scroll view
                  padding: EdgeInsets.only(
                    left: screenWidth * 0.1,
                    right: screenWidth * 0.1,
                    bottom: MediaQuery.of(
                      context,
                    ).viewInsets.bottom, // Moves with keyboard
                  ),
                  child: ConstrainedBox(
                    // Force the column to be AT LEAST as tall as the viewport
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      // This Column now controls the main layout
                      mainAxisAlignment: MainAxisAlignment
                          .spaceBetween, // Pushes top/bottom apart
                      children: [
                        // --- TOP CONTENT ---
                        // This column holds the form elements
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: constraints.maxHeight * 0.05,
                            ), // Relative spacing
                            Text(
                              'ตั้งค่าโปรไฟล์',
                              style: TextStyle(
                                fontFamily: 'NotoLoopedThaiUI',
                                fontSize: screenWidth * 0.08,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2E88F3),
                              ),
                            ),
                            SizedBox(height: constraints.maxHeight * 0.01),
                            Text(
                              'กรุณากรอกข้อมูลเพื่อสร้างโปรไฟล์ของคุณ',
                              style: TextStyle(
                                fontFamily: 'NotoLoopedThaiUI',
                                fontSize: screenWidth * 0.04,
                                color: const Color(0xFF6B7280),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: constraints.maxHeight * 0.04),

                            // Profile Image Section
                            GestureDetector(
                              onTap: _selectProfileImage,
                              child: CircleAvatar(
                                radius: screenWidth * 0.18,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: _imageFile != null
                                    ? FileImage(File(_imageFile!.path))
                                    : null,
                                child: _imageFile == null
                                    ? Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            size: screenWidth * 0.1,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'เพิ่มรูป',
                                            style: TextStyle(
                                              fontFamily: 'NotoLoopedThaiUI',
                                              fontSize: screenWidth * 0.03,
                                              color: Colors.grey.shade500,
                                            ),
                                          ),
                                        ],
                                      )
                                    : null,
                              ),
                            ),
                            SizedBox(height: constraints.maxHeight * 0.04),

                            // Form Container
                            Container(
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
                                  // Username
                                  Text(
                                    'ชื่อผู้ใช้ *',
                                    style: TextStyle(
                                      fontFamily: 'NotoLoopedThaiUI',
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _usernameController,
                                    onChanged: (_) => setState(() {}),
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'กรอกชื่อที่ต้องการให้แสดง',
                                      hintStyle: TextStyle(
                                        fontFamily: 'NotoLoopedThaiUI',
                                        color: Colors.grey[400],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey[400]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey[400]!,
                                        ),
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
                                  const SizedBox(height: 20),
                                  // Description
                                  Text(
                                    'คำอธิบายเกี่ยวกับตัวคุณ',
                                    style: TextStyle(
                                      fontFamily: 'NotoLoopedThaiUI',
                                      fontSize: screenWidth * 0.04,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF374151),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _descriptionController,
                                    maxLines: 3,
                                    maxLength: 150,
                                    textInputAction: TextInputAction.done,
                                    decoration: InputDecoration(
                                      hintText:
                                          'เล่าเกี่ยวกับตัวคุณสั้นๆ (ไม่บังคับ)',
                                      hintStyle: TextStyle(
                                        fontFamily: 'NotoLoopedThaiUI',
                                        color: Colors.grey[400],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey[400]!,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Colors.grey[400]!,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: const BorderSide(
                                          color: Color(0xFF2E88F3),
                                          width: 2,
                                        ),
                                      ),
                                      counterStyle: const TextStyle(
                                        fontFamily: 'NotoLoopedThaiUI',
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // --- END TOP CONTENT ---

                        // --- BOTTOM BUTTON ---
                        // This will be pushed to the bottom by MainAxisAlignment.spaceBetween
                        Padding(
                          padding: EdgeInsets.only(
                            top:
                                constraints.maxHeight *
                                0.05, // Space above button
                            bottom:
                                constraints.maxHeight *
                                0.05, // Space below button
                          ),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : CustomButton(
                                  text: 'สร้างโปรไฟล์',
                                  isEnabled: _isFormValid,
                                  onPressed: _completeSetup,
                                ),
                        ),
                        // --- END BOTTOM BUTTON ---
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
