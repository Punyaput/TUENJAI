// lib/screens/profile_setup_screen.dart

import 'dart:io'; // Import for File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // --- NEW: State for image file ---
  XFile? _imageFile; // image_picker returns XFile
  final ImagePicker _picker = ImagePicker(); // Instance of image picker
  // --- END NEW ---

  bool _isLoading = false;

  bool get _isFormValid {
    return _usernameController.text.trim().isNotEmpty && !_isLoading;
  }

  // --- UPDATED: Image selection logic ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800, // Optional: Resize image
        imageQuality: 70, // Optional: Compress image
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
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
                      _pickImage(ImageSource.camera); // <-- Use _pickImage
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'แกลเลอรี่',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery); // <-- Use _pickImage
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
    // ... (This widget is unchanged) ...
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF2E88F3).withOpacity(0.1),
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

  // --- NEW: Function to upload image to Firebase Storage ---
  Future<String?> _uploadImageToStorage(XFile imageFile, String userId) async {
    try {
      // Create a unique file name (e.g., using userId and timestamp)
      final String fileName =
          'profile_pics/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );

      // Upload the file
      final UploadTask uploadTask = storageRef.putFile(
        File(imageFile.path),
      ); // Convert XFile to File

      // Get download URL after upload completes
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Image uploaded successfully: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("Error uploading image: $e");
      _showError("เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e");
      return null; // Return null if upload fails
    }
  }
  // --- END NEW ---

  // --- UPDATED: Save profile data including profile picture URL ---
  void _completeSetup() async {
    if (!_isFormValid) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final db = FirebaseFirestore.instance;
      String? profilePicUrl; // Variable to hold the URL

      // --- Upload image if one was selected ---
      if (_imageFile != null) {
        profilePicUrl = await _uploadImageToStorage(_imageFile!, user.uid);
        if (profilePicUrl == null) {
          // Handle upload failure (maybe prevent saving profile?)
          setState(() {
            _isLoading = false;
          });
          return; // Stop if upload failed
        }
      }
      // --- End image upload ---

      // Update the user document in Firestore
      await db.collection('users').doc(user.uid).update({
        'username': _usernameController.text.trim(),
        'description': _descriptionController.text.trim(),
        // Only add/update the URL if upload was successful
        if (profilePicUrl != null) 'profilePicUrl': profilePicUrl,
        'profileLastUpdated': FieldValue.serverTimestamp(),
      });

      print('Profile setup completed for user: ${user.uid}');
      if (profilePicUrl != null) print('Profile Pic URL: $profilePicUrl');

      // Navigate to Role Selection screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
        );
      }
    } catch (e) {
      print('Error completing profile setup: $e');
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
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.18,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: screenWidth * 0.1,
                right: screenWidth * 0.1,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: screenHeight * 0.05,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ตั้งค่าโปรไฟล์',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.08,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2E88F3),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'กรุณากรอกข้อมูลเพื่อสร้างโปรไฟล์ของคุณ',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.04,
                      color: const Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: screenHeight * 0.04),

                  // --- UPDATED Profile Image Section ---
                  GestureDetector(
                    onTap: _selectProfileImage,
                    child: CircleAvatar(
                      radius: screenWidth * 0.18, // Make it larger
                      backgroundColor: Colors.grey.shade200, // Background color
                      // --- Show picked image or placeholder ---
                      backgroundImage: _imageFile != null
                          ? FileImage(
                              File(_imageFile!.path),
                            ) // Display selected File image
                          : null, // No background image if no file
                      child: _imageFile == null
                          ? Column(
                              // Placeholder icon/text
                              mainAxisAlignment: MainAxisAlignment.center,
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
                          : null, // Don't show icon/text if image is selected
                    ),
                  ),

                  // --- END UPDATED ---
                  SizedBox(height: screenHeight * 0.04),
                  Container(
                    // Form Container
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
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
                            hintText: 'เล่าเกี่ยวกับตัวคุณสั้นๆ (ไม่บังคับ)',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              color: Colors.grey[400],
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[400]!),
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
                  SizedBox(height: screenHeight * 0.05),
                  // Button
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    CustomButton(
                      text: 'สร้างโปรไฟล์',
                      isEnabled: _isFormValid,
                      onPressed: _completeSetup,
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
    _usernameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
