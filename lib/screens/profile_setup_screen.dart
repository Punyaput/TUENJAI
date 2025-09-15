import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String? _selectedProfileImage;

  bool get _isFormValid {
    return _usernameController.text.trim().isNotEmpty;
  }

  void _selectProfileImage() {
    // Show image picker options
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
                      setState(() {
                        _selectedProfileImage = 'camera';
                      });
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'แกลเลอรี่',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedProfileImage = 'gallery';
                      });
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
            child: Icon(
              icon,
              size: 30,
              color: const Color(0xFF2E88F3),
            ),
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

  void _completeSetup() {
    if (_isFormValid) {
      print('Profile setup completed:');
      print('Username: ${_usernameController.text}');
      print('Description: ${_descriptionController.text}');
      print('Profile Image: $_selectedProfileImage');
      
      // Navigate to main app or show success
      // For now, just show a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'โปรไฟล์ถูกสร้างเรียบร้อยแล้ว',
            style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          backgroundColor: Color(0xFF7ED6A8),
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
      body: SafeArea(   // ✅ Wrap here
        child: Stack(
          children: [
            // Only bottom circles (no top circles as specified)
            Positioned(
              bottom: -screenWidth * 0.18,
              left: -screenWidth * 0.2,
              child: const BottomBackgroundCircles(),
            ),

            // Main content
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: screenWidth * 0.1,
                right: screenWidth * 0.1,
                bottom: MediaQuery.of(context).viewInsets.bottom, // 👈 keyboard-aware padding
              ),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.08),

                  // Header
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

                  // Profile Image Section
                  GestureDetector(
                    onTap: _selectProfileImage,
                    child: Container(
                      width: screenWidth * 0.3,
                      height: screenWidth * 0.3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(
                          color: const Color(0xFFD1D5DB),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _selectedProfileImage != null
                          ? Icon(
                              _selectedProfileImage == 'camera'
                                  ? Icons.camera_alt
                                  : Icons.photo,
                              size: screenWidth * 0.1,
                              color: const Color(0xFF2E88F3),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo,
                                  size: screenWidth * 0.08,
                                  color: const Color(0xFFD1D5DB),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'เพิ่มรูป',
                                  style: TextStyle(
                                    fontFamily: 'NotoLoopedThaiUI',
                                    fontSize: screenWidth * 0.03,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.04),

                  // Form Container
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
                        // Username Field
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
                          decoration: InputDecoration(
                            hintText: 'กรอกชื่อผู้ใช้',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E88F3),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Description Field
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
                          decoration: InputDecoration(
                            hintText: 'เล่าเกี่ยวกับตัวคุณ (ไม่บังคับ)',
                            hintStyle: TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF2E88F3),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
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

                  // Complete Setup Button
                  CustomButton(
                    text: 'สร้างโปรไฟล์',
                    isEnabled: _isFormValid,
                    onPressed: _completeSetup,
                  ),

                  SizedBox(height: screenHeight * 0.15),
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