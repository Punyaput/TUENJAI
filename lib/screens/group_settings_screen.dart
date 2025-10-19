// lib/screens/group_settings_screen.dart

import 'dart:io'; // For File
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart'; // For image upload
import 'package:image_picker/image_picker.dart'; // For image picking
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_button.dart'; // For potential future use, e.g., leave group

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
  // Pass group name for initial display while loading
  final String initialGroupName;

  const GroupSettingsScreen({
    super.key,
    required this.groupId,
    required this.initialGroupName,
  });

  @override
  State<GroupSettingsScreen> createState() => _GroupSettingsScreenState();
}

class _GroupSettingsScreenState extends State<GroupSettingsScreen> {
  // Group Data State
  String? _groupName;
  String? _groupDescription;
  String? _groupImageUrl;
  String? _inviteCode;
  List<Map<String, dynamic>> _membersData =
      []; // Store member details (name, role)

  // Current User State
  String?
  _currentUserRole; // User's overall role ('caretaker' or 'carereceiver')
  bool _isCurrentUserGroupCaretaker =
      false; // Is the current user a caretaker IN THIS GROUP?

  // Image Picking State
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Loading States
  bool _isLoadingGroupData = true;
  bool _isUploadingImage = false;
  bool _isDeletingGroup = false;

  @override
  void initState() {
    super.initState();
    _groupName = widget.initialGroupName; // Show initial name immediately
    _fetchGroupAndUserData();
  }

  // Fetch group details and current user's role/status within the group
  Future<void> _fetchGroupAndUserData() async {
    setState(() {
      _isLoadingGroupData = true;
    });
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Handle not logged in
      if (mounted) Navigator.pop(context); // Go back if no user
      return;
    }

    try {
      // Fetch current user's general role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      if (userDoc.exists && mounted) {
        _currentUserRole = userDoc.data()?['role'];
      }

      // Fetch group document
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();

      if (!groupDoc.exists) {
        throw Exception("Group not found");
      }

      final data = groupDoc.data()!;
      _inviteCode = data['inviteCode'];
      _groupName =
          data['groupName'] ??
          widget.initialGroupName; // Update with fetched name
      _groupDescription = data['description'] ?? '';
      _groupImageUrl = data['groupImageUrl']; // Get image URL

      // Fetch member details and determine current user's role *within the group*
      final List<dynamic> memberIds = data['members'] ?? [];
      final List<Map<String, dynamic>> fetchedMembersData = [];
      _isCurrentUserGroupCaretaker = false; // Reset before check

      if (memberIds.isNotEmpty) {
        // Fetch user documents for member IDs
        // You might already have a function for this, adapt if necessary
        final usersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: memberIds)
            .get();
        Map<String, Map<String, dynamic>> userDataMap = {
          for (var doc in usersQuery.docs) doc.id: doc.data(),
        };

        for (String memberId in memberIds.cast<String>()) {
          final memberData = userDataMap[memberId];
          final memberRole = memberData?['role'] ?? 'unknown';
          fetchedMembersData.add({
            'uid': memberId,
            'username': memberData?['username'] ?? 'Unknown Member',
            'role': memberRole,
            'profilePicUrl': memberData?['profilePicUrl'], // Get profile pic
          });
          // Check if the currently logged-in user is a caretaker in this group
          if (memberId == currentUser.uid && memberRole == 'caretaker') {
            _isCurrentUserGroupCaretaker = true;
          }
        }
        // Sort members? Maybe put caretakers first? (Optional)
        fetchedMembersData.sort((a, b) => a['role'] == 'caretaker' ? -1 : 1);
      }

      if (mounted) {
        setState(() {
          _membersData = fetchedMembersData;
          _isLoadingGroupData = false;
        });
      }
    } catch (e) {
      print("Error fetching group/user data: $e");
      if (mounted) {
        setState(() {
          _isLoadingGroupData = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // Optionally pop if group fetch failed critically
        if (e.toString().contains("Group not found") && mounted)
          Navigator.pop(context);
      }
    }
  }

  // --- Image Handling ---
  Future<void> _pickGroupImage(ImageSource source) async {
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
        _uploadGroupImage(); // Immediately start upload after picking
      }
    } catch (e) {
      _handleError("Error picking image", e);
    }
  }

  void _showImagePickerOptions() {
    if (!_isCurrentUserGroupCaretaker) return; // Permission check
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
                'เลือกรูปกลุ่ม',
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
                      _pickGroupImage(ImageSource.camera);
                    },
                  ),
                  _buildImageOption(
                    icon: Icons.photo_library,
                    label: 'แกลเลอรี่',
                    onTap: () {
                      Navigator.pop(context);
                      _pickGroupImage(ImageSource.gallery);
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

  Future<void> _uploadGroupImage() async {
    if (_imageFile == null) return;
    setState(() {
      _isUploadingImage = true;
    });

    try {
      final String fileName =
          'group_pics/${widget.groupId}/image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child(
        fileName,
      );
      final UploadTask uploadTask = storageRef.putFile(File(_imageFile!.path));
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Update Firestore with the new URL
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'groupImageUrl': downloadUrl,
            'lastUpdatedAt': FieldValue.serverTimestamp(), // Track updates
          });

      if (mounted) {
        setState(() {
          _groupImageUrl = downloadUrl; // Update local state to show new image
          _imageFile = null; // Clear picked file
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตรูปกลุ่มแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
      // TODO: Delete old image from storage if one existed
    } catch (e) {
      _handleError("Error uploading group image", e);
      if (mounted)
        setState(() {
          _isUploadingImage = false;
        });
    }
  }
  // --- End Image Handling ---

  // --- Edit Name/Description ---
  void _showEditDialog(String field, String initialValue) {
    if (!_isCurrentUserGroupCaretaker) return; // Permission check

    final TextEditingController controller = TextEditingController(
      text: initialValue,
    );
    String title = field == 'groupName' ? 'แก้ไขชื่อกลุ่ม' : 'แก้ไขคำอธิบาย';
    String label = field == 'groupName' ? 'ชื่อกลุ่ม *' : 'คำอธิบาย';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          maxLines: field == 'description' ? 3 : 1,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'ยกเลิก',
              style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newValue = controller.text.trim();
              // Basic validation for name
              if (field == 'groupName' && newValue.isEmpty) return;

              Navigator.pop(context); // Close dialog
              await _updateGroupField(field, newValue);
            },
            child: const Text(
              'บันทึก',
              style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateGroupField(String field, String value) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
            field: value,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        setState(() {
          // Update local state immediately
          if (field == 'groupName') _groupName = value;
          if (field == 'description') _groupDescription = value;
        });
      }
    } catch (e) {
      _handleError("Error updating $field", e);
    }
  }
  // --- End Edit Name/Description ---

  // --- Delete Group ---
  Future<void> _deleteGroup() async {
    setState(() {
      _isDeletingGroup = true;
    });
    try {
      // Basic delete - does not delete subcollections (tasks)
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .delete();
      // TODO (Advanced): Could trigger a Cloud Function to delete tasks and update user joinedGroups.

      if (mounted) {
        int count = 0;
        Navigator.of(
          context,
        ).popUntil((_) => count++ >= 2); // Go back 2 screens
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบกลุ่มเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _handleError("Error deleting group", e);
      if (mounted)
        setState(() {
          _isDeletingGroup = false;
        });
    }
  }

  void _showDeleteGroupDialog() {
    // Permission check already done by button visibility
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ยืนยันการลบกลุ่ม',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: const Text(
            'คุณแน่ใจหรือไม่ว่าต้องการลบกลุ่มนี้อย่างถาวร? ข้อมูลกลุ่มจะถูกลบ (แต่งานต่างๆ จะยังคงอยู่)',
            style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            _isDeletingGroup
                ? const CircularProgressIndicator()
                : TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _deleteGroup();
                    },
                    child: const Text(
                      'ลบกลุ่ม',
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }
  // --- End Delete Group ---

  // --- Generic Error Handler ---
  void _handleError(String contextMessage, dynamic error) {
    print("$contextMessage: $error");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เกิดข้อผิดพลาด: $error',
            style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          _groupName ?? 'ตั้งค่ากลุ่ม',
        ), // Show fetched name or initial
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),
            _isLoadingGroupData
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    // Add pull-to-refresh
                    onRefresh: _fetchGroupAndUserData,
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.06,
                        vertical: 20,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Group Image Section
                          Center(
                            child: Stack(
                              alignment: Alignment.bottomRight,
                              children: [
                                CircleAvatar(
                                  radius: screenWidth * 0.2,
                                  backgroundColor: Colors.grey.shade300,
                                  backgroundImage: _imageFile != null
                                      ? FileImage(File(_imageFile!.path))
                                            as ImageProvider
                                      : (_groupImageUrl != null &&
                                                _groupImageUrl!.isNotEmpty
                                            ? NetworkImage(_groupImageUrl!)
                                            : null),
                                  child:
                                      (_imageFile == null &&
                                          (_groupImageUrl == null ||
                                              _groupImageUrl!.isEmpty))
                                      ? Icon(
                                          Icons.group,
                                          size: screenWidth * 0.15,
                                          color: Colors.grey.shade500,
                                        )
                                      : null,
                                ),
                                if (_isCurrentUserGroupCaretaker) // Only show edit icon if caretaker
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Material(
                                      // Wrap IconButton in Material for splash
                                      color: Theme.of(context).primaryColor,
                                      shape: const CircleBorder(),
                                      elevation: 2.0,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _showImagePickerOptions,
                                        child: Container(
                                          // Container ensures padding and border visibility
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                          child: _isUploadingImage
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : Icon(
                                                  Icons.edit,
                                                  color: Colors.white,
                                                  size: screenWidth * 0.04,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Group Name and Description Section
                          _buildInfoSection(
                            label: 'ชื่อกลุ่ม',
                            value: _groupName ?? '...',
                            onEdit: _isCurrentUserGroupCaretaker
                                ? () => _showEditDialog(
                                    'groupName',
                                    _groupName ?? '',
                                  )
                                : null,
                            screenWidth: screenWidth,
                          ),
                          const SizedBox(height: 16),
                          _buildInfoSection(
                            label: 'คำอธิบาย',
                            value:
                                _groupDescription != null &&
                                    _groupDescription!.isNotEmpty
                                ? _groupDescription!
                                : 'ไม่มีคำอธิบาย',
                            valueColor:
                                _groupDescription != null &&
                                    _groupDescription!.isNotEmpty
                                ? null
                                : Colors.grey,
                            onEdit: _isCurrentUserGroupCaretaker
                                ? () => _showEditDialog(
                                    'description',
                                    _groupDescription ?? '',
                                  )
                                : null,
                            screenWidth: screenWidth,
                          ),
                          const SizedBox(height: 24),

                          // Invite Code Section (visible to caretakers)
                          if (_isCurrentUserGroupCaretaker) ...[
                            _buildInviteCodeSection(screenWidth),
                            const SizedBox(height: 24),
                          ],

                          // Members List Section
                          _buildMembersList(screenWidth),
                          const SizedBox(height: 24),

                          // Delete Button (visible to caretakers)
                          if (_isCurrentUserGroupCaretaker)
                            Center(
                              child: TextButton.icon(
                                icon: const Icon(
                                  Icons.delete_forever,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'ลบกลุ่มนี้',
                                  style: TextStyle(
                                    fontFamily: 'NotoLoopedThaiUI',
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _isDeletingGroup
                                    ? null
                                    : _showDeleteGroupDialog,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 20), // Bottom padding
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  // Helper widget for displaying Name/Description with an optional Edit button
  Widget _buildInfoSection({
    required String label,
    required String value,
    required double screenWidth,
    Color? valueColor,
    VoidCallback? onEdit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: screenWidth * 0.035,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: screenWidth * 0.045,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit !=
              null) // Show edit button only if callback is provided (i.e., user has permission)
            IconButton(
              icon: Icon(Icons.edit_note, color: Colors.grey[500], size: 20),
              onPressed: onEdit,
              tooltip: 'แก้ไข',
            ),
        ],
      ),
    );
  }

  Widget _buildInviteCodeSection(double screenWidth) {
    if (_inviteCode == null)
      return const SizedBox.shrink(); // Don't show if no code
    return Container(
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
          const Text(
            'รหัสเข้าร่วมกลุ่ม',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          QrImageView(
            data: _inviteCode!,
            version: QrVersions.auto,
            size: screenWidth * 0.5,
          ),
          const SizedBox(height: 16),
          SelectableText(
            // Make the code selectable
            _inviteCode!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: screenWidth * 0.08,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: const Color(0xFF2E88F3),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'แสดง QR code นี้ให้สมาชิกคนอื่นสแกน\nหรือคัดลอกรหัส',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMembersList(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 20,
      ), // Consistent padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'สมาชิก (${_membersData.length})',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          if (_membersData.isEmpty)
            const Text(
              'ยังไม่มีสมาชิกอื่น',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                color: Colors.grey,
              ),
            ),
          ListView.separated(
            // Use ListView.separated for dividers
            shrinkWrap: true, // Important inside SingleChildScrollView
            physics:
                const NeverScrollableScrollPhysics(), // Disable ListView's own scrolling
            itemCount: _membersData.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final member = _membersData[index];
              final isCaretaker = member['role'] == 'caretaker';
              final profilePicUrl = member['profilePicUrl'] as String?;

              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      (profilePicUrl != null && profilePicUrl.isNotEmpty)
                      ? NetworkImage(profilePicUrl)
                      : null,
                  child: (profilePicUrl == null || profilePicUrl.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 20,
                          color: Colors.grey.shade400,
                        )
                      : null,
                ),
                title: Text(
                  member['username'],
                  style: const TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Text(
                  isCaretaker ? 'ผู้ดูแล' : 'ผู้รับการดูแล',
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: 14,
                    color: isCaretaker
                        ? Theme.of(context).primaryColor
                        : Colors.green[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // Optional: Add actions like "Remove member" for caretakers (more complex)
              );
            },
          ),
        ],
      ),
    );
  }
} // End of _GroupSettingsScreenState
