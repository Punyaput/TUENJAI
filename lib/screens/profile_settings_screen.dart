// lib/screens/profile_settings_screen.dart

import 'dart:io'; // Import for File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/custom_button.dart';
import '../widgets/background_circles.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // --- NEW: State for image file and existing URL ---
  XFile? _imageFile; // New image selected by user
  String? _existingProfilePicUrl; // URL fetched from Firestore
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = true; // Loading initial data
  bool _isSaving = false; // Saving changes
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Load existing data when screen opens
  }

  // --- NEW: Load user data from Firestore ---
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Handle not logged in state if needed, maybe pop screen
      if (mounted)
        setState(() {
          _isLoading = false;
        });
      _showError("ไม่พบผู้ใช้งาน");
      Navigator.pop(context); // Go back if no user
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data()!;
        _usernameController.text = data['username'] ?? '';
        _descriptionController.text = data['description'] ?? '';
        _existingProfilePicUrl = data['profilePicUrl']; // Store existing URL
        setState(() {
          _isLoading = false;
        });
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
          });
        _showError("ไม่พบข้อมูลโปรไฟล์");
      }
    } catch (e) {
      print("Error loading user data: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError("เกิดข้อผิดพลาดในการโหลดข้อมูล: $e");
      }
    }
  }
  // --- END NEW ---

  bool get _isFormValid {
    return _usernameController.text.trim().isNotEmpty && !_isSaving;
  }

  // --- UPDATED: Image selection logic (same as setup) ---
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 70,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _imageFile = pickedFile; // Store the newly picked file
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
          /* ... (modal content is the same as setup) ... */
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

  // --- Upload Image function (same as setup) ---
  Future<String?> _uploadImageToStorage(XFile imageFile, String userId) async {
    print('Starting image upload for user: $userId'); // Log start
    try {
      final String fileName =
          'profile_pics/${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      print('  Generated fileName: $fileName'); // Log filename

      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );
      print(
        '  Created storage reference: ${storageRef.fullPath}',
      ); // Log full path

      final UploadTask uploadTask = storageRef.putFile(File(imageFile.path));
      print(
        '  Upload task created. Awaiting completion...',
      ); // Log before await

      // Listen to task state changes for more detail (optional but helpful)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
          '    Task state: ${snapshot.state} (${snapshot.bytesTransferred}/${snapshot.totalBytes})',
        );
      });

      final TaskSnapshot snapshot =
          await uploadTask; // Wait for upload to complete
      print(
        '  Upload task completed. State: ${snapshot.state}',
      ); // Log completion state

      if (snapshot.state == TaskState.success) {
        print('  Attempting to get download URL...'); // Log before getting URL
        final String downloadUrl = await snapshot.ref.getDownloadURL();
        print("  Image uploaded successfully: $downloadUrl"); // Log success URL
        return downloadUrl;
      } else {
        print(
          '  Upload task did not succeed. State: ${snapshot.state}',
        ); // Log failure state
        _showError("การอัปโหลดรูปภาพไม่สำเร็จ (State: ${snapshot.state})");
        return null;
      }
    } catch (e) {
      print(
        "!!! Error during image upload process: $e",
      ); // Log the specific error caught
      // Check if it's a StorageException for more details
      if (e is FirebaseException) {
        print("FirebaseException Code: ${e.code}");
        print("FirebaseException Message: ${e.message}");
      }
      _showError("เกิดข้อผิดพลาดในการอัปโหลดรูปภาพ: $e");
      return null; // Return null if upload fails
    }
  }

  // --- UPDATED: Save profile changes ---
  void _saveProfile() async {
    if (!_isFormValid) return;
    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in.");

      final db = FirebaseFirestore.instance;
      String? profilePicUrl = _existingProfilePicUrl; // Start with existing URL

      // --- Upload NEW image if one was selected ---
      if (_imageFile != null) {
        profilePicUrl = await _uploadImageToStorage(_imageFile!, user.uid);
        if (profilePicUrl == null) {
          // Handle upload failure
          setState(() {
            _isSaving = false;
          });
          return; // Stop saving if upload failed
        }
        // TODO: Optionally delete the OLD image from Firebase Storage here
        // Requires storing the old file path/ref, not just the URL
      }
      // --- End image upload ---

      // Data to update in Firestore
      Map<String, dynamic> updateData = {
        'username': _usernameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'profileLastUpdated': FieldValue.serverTimestamp(),
      };
      // Only include profilePicUrl if it's new or was already there
      if (profilePicUrl != null || _imageFile != null) {
        updateData['profilePicUrl'] =
            profilePicUrl; // Set to new URL or potentially null if removed?
      }
      // Consider how to handle REMOVING a profile picture (set URL to null or delete field?)

      // Update the user document
      await db.collection('users').doc(user.uid).update(updateData);

      print('Profile updated for user: ${user.uid}');
      if (profilePicUrl != null) print('Profile Pic URL: $profilePicUrl');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'บันทึกข้อมูลเรียบร้อยแล้ว',
              style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
            ),
            backgroundColor: Color(0xFF7ED6A8),
          ), // Green
        );
        Navigator.pop(context); // Go back to settings screen
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        _showError('เกิดข้อผิดพลาดในการบันทึก: $e');
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
      resizeToAvoidBottomInset: true, // Allow resize for keyboard
      appBar: AppBar(
        /* ... (AppBar is mostly unchanged) ... */
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ตั้งค่าโปรไฟล์',
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
              bottom: -screenWidth * 0.18,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),

            // Show loading indicator while fetching data
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SingleChildScrollView(
                // Allow scrolling
                padding: EdgeInsets.only(
                  left: screenWidth * 0.1,
                  right: screenWidth * 0.1,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  top: screenHeight * 0.05,
                ),
                child: Column(
                  children: [
                    // --- UPDATED Profile Image Section ---
                    GestureDetector(
                      onTap: _selectProfileImage,
                      child: Stack(
                        // Wrap with Stack
                        alignment: Alignment
                            .bottomRight, // Align overlay to bottom-right
                        children: [
                          CircleAvatar(
                            // The main avatar
                            radius: screenWidth * 0.18,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: _imageFile != null
                                ? FileImage(File(_imageFile!.path))
                                      as ImageProvider
                                : (_existingProfilePicUrl != null &&
                                          _existingProfilePicUrl!.isNotEmpty
                                      ? NetworkImage(_existingProfilePicUrl!)
                                      : null),
                            child:
                                (_imageFile == null &&
                                    (_existingProfilePicUrl == null ||
                                        _existingProfilePicUrl!.isEmpty))
                                ? Column(
                                    // Placeholder
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.person_outline,
                                        size: screenWidth * 0.1,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'แก้ไขรูป',
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
                          // --- The Overlay using Positioned ---
                          Positioned(
                            bottom: 4, // Adjust position slightly
                            right: 4, // Adjust position slightly
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).primaryColor, // Use theme color
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: screenWidth * 0.04,
                              ),
                            ),
                          ),
                          // --- End Overlay ---
                        ],
                      ),
                    ),

                    // --- END UPDATED ---
                    SizedBox(height: screenHeight * 0.04),

                    // Form Container
                    Container(
                      /* ... (Form content is unchanged) ... */
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

                    SizedBox(height: screenHeight * 0.05),

                    // Save Button
                    if (_isSaving)
                      const CircularProgressIndicator()
                    else
                      CustomButton(
                        text: 'บันทึก',
                        isEnabled: _isFormValid,
                        onPressed: _saveProfile,
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
} // End of _ProfileSettingsScreenState
