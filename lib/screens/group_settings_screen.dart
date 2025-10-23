// lib/screens/group_settings_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/background_circles.dart';
// import '../widgets/custom_button.dart';

class GroupSettingsScreen extends StatefulWidget {
  final String groupId;
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
  List<Map<String, dynamic>> _membersData = [];
  List<Map<String, dynamic>> _pendingMembersData = [];

  // Current User State
  String _currentUserId = '';
  bool _isCurrentUserGroupCaretaker = false;

  // Image Picking State
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  // Loading States
  bool _isLoadingGroupData = true;
  bool _isUploadingImage = false;
  bool _isDeletingGroup = false;

  final Map<String, Map<String, dynamic>> _userCache = {};

  @override
  void initState() {
    super.initState();
    _groupName = widget.initialGroupName;
    _fetchGroupAndUserData();
  }

  Future<void> _fetchGroupAndUserData() async {
    setState(() {
      _isLoadingGroupData = true;
    });
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    _currentUserId = currentUser.uid;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (userDoc.exists && mounted) {
        _userCache[_currentUserId] = userDoc.data()!;
      }

      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (!groupDoc.exists) throw Exception("Group not found");

      final data = groupDoc.data()!;
      _inviteCode = data['inviteCode'];
      _groupName = data['groupName'] ?? widget.initialGroupName;
      _groupDescription = data['description'] ?? '';
      _groupImageUrl = data['groupImageUrl'];

      final List<String> memberIds =
          (data['members'] as List?)?.cast<String>() ?? [];
      final List<String> pendingIds =
          (data['pendingRequests'] as List?)?.cast<String>() ?? [];
      _isCurrentUserGroupCaretaker = false;

      final allIdsToFetch = {...memberIds, ...pendingIds}.toList();
      // --- Fetch user data for all members/pending, including potential ghosts ---
      // (Ghosts won't be in the result, which is fine)
      await _fetchUsernames(allIdsToFetch);

      final List<Map<String, dynamic>> fetchedMembersData = [];
      final List<Map<String, dynamic>> fetchedPendingData = [];

      // Process members
      for (String memberId in memberIds) {
        final memberData = _userCache[memberId]; // Get from cache
        final memberRole = memberData?['role'] ?? 'unknown';
        fetchedMembersData.add({
          'uid': memberId,
          // If memberData is null (ghost user), show a fallback
          'username':
              memberData?['username'] ?? 'ผู้ใช้ที่ถูกลบ', // "Deleted User"
          'role': memberRole,
          'profilePicUrl': memberData?['profilePicUrl'],
        });
        if (memberId == _currentUserId && memberRole == 'caretaker') {
          _isCurrentUserGroupCaretaker = true;
        }
      }

      // Process pending requests
      for (String memberId in pendingIds) {
        final memberData = _userCache[memberId];
        // If a pending user deleted their account, they just won't show up here
        // which is fine. Or show fallback:
        if (memberData != null) {
          fetchedPendingData.add({
            'uid': memberId,
            'username': memberData['username'] ?? 'กำลังโหลด...',
            'role': memberData['role'] ?? 'unknown',
            'profilePicUrl': memberData['profilePicUrl'],
          });
        }
      }

      fetchedMembersData.sort((a, b) => a['role'] == 'caretaker' ? -1 : 1);

      if (mounted) {
        setState(() {
          _membersData = fetchedMembersData;
          _pendingMembersData = fetchedPendingData;
          _isLoadingGroupData = false;
        });
      }
    } catch (e) {
      print("Error fetching group/user data: $e");
      if (mounted) {
        setState(() {
          _isLoadingGroupData = false;
        });
        _handleError("Error fetching group data", e);
        if (e.toString().contains("Group not found") && mounted)
          Navigator.pop(context);
      }
    }
  }

  Future<void> _fetchUsernames(List<String> userIds) async {
    List<String> idsToFetch = [];
    for (String id in userIds.toSet()) {
      if (!_userCache.containsKey(id) && id.isNotEmpty) {
        idsToFetch.add(id);
      }
    }
    if (idsToFetch.isEmpty) return;
    try {
      for (var i = 0; i < idsToFetch.length; i += 10) {
        var batchIds = idsToFetch.sublist(
          i,
          i + 10 > idsToFetch.length ? idsToFetch.length : i + 10,
        );
        if (batchIds.isEmpty) continue;
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: batchIds)
            .get();
        for (var doc in querySnapshot.docs) {
          _userCache[doc.id] = doc.data();
        }
      }
    } catch (e) {
      print("Error batch fetching usernames: $e");
    }
  }

  // --- Image Handling ---
  Future<void> _pickGroupImage(ImageSource source) async {
    /* ... (unchanged) ... */
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
        _uploadGroupImage();
      }
    } catch (e) {
      _handleError("Error picking image", e);
    }
  }

  void _showImagePickerOptions() {
    /* ... (unchanged) ... */
    if (!_isCurrentUserGroupCaretaker) return;
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
    /* ... (unchanged) ... */
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
    /* ... (unchanged) ... */
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
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'groupImageUrl': downloadUrl,
            'lastUpdatedAt': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        setState(() {
          _groupImageUrl = downloadUrl;
          _imageFile = null;
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อัปเดตรูปกลุ่มแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _handleError("Error uploading group image", e);
      if (mounted)
        setState(() {
          _isUploadingImage = false;
        });
    }
  }

  // --- Edit Name/Description ---
  void _showEditDialog(String field, String initialValue) {
    /* ... (unchanged) ... */
    if (!_isCurrentUserGroupCaretaker) return;
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
              if (field == 'groupName' && newValue.isEmpty) return;
              Navigator.pop(context);
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
    /* ... (unchanged) ... */
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
          if (field == 'groupName') _groupName = value;
          if (field == 'description') _groupDescription = value;
        });
      }
    } catch (e) {
      _handleError("Error updating $field", e);
    }
  }

  // --- Delete Group ---
  Future<void> _deleteGroup() async {
    /* ... (unchanged) ... */
    setState(() {
      _isDeletingGroup = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .delete();
      if (mounted) {
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 2);
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
    /* ... (unchanged) ... */
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

  // --- Remove Member Logic ---
  void _showRemoveMemberDialog(String memberId, String username) {
    /* ... (unchanged) ... */
    if (!_isCurrentUserGroupCaretaker || memberId == _currentUserId) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'นำสมาชิกออก',
          style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการนำ "$username" ออกจากกลุ่มนี้?',
          style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
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
              Navigator.pop(context);
              await _removeMember(memberId);
            },
            child: const Text(
              'นำออก',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UPDATED: Remove Member Logic ---
  Future<void> _removeMember(String memberId) async {
    if (!_isCurrentUserGroupCaretaker) return;
    setState(() {
      _isLoadingGroupData = true;
    }); // Show loading
    try {
      final db = FirebaseFirestore.instance;

      // 1. Check if the user document exists
      final userRef = db.collection('users').doc(memberId);
      final userDoc = await userRef.get();

      // 2. Prepare batch write
      final batch = db.batch();
      final groupRef = db.collection('groups').doc(widget.groupId);

      // 3. ALWAYS remove member from the group's 'members' list
      batch.update(groupRef, {
        'members': FieldValue.arrayRemove([memberId]),
      });

      // 4. ONLY update the user's document if it still exists
      if (userDoc.exists) {
        batch.update(userRef, {
          'joinedGroups': FieldValue.arrayRemove([widget.groupId]),
        });
      } else {
        print("User $memberId document not found. Skipping user update.");
      }

      // 5. Commit the batch
      await batch.commit();

      _fetchGroupAndUserData(); // Refresh list (this will stop loading state)
    } catch (e) {
      _handleError("Error removing member", e);
      if (mounted)
        setState(() {
          _isLoadingGroupData = false;
        });
    }
  }
  // --- END UPDATED LOGIC ---

  // --- Accept/Deny Logic ---
  Future<void> _acceptMember(String memberId) async {
    /* ... (unchanged) ... */
    if (!_isCurrentUserGroupCaretaker) return;
    setState(() {
      _isLoadingGroupData = true;
    });
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();
      final groupRef = db.collection('groups').doc(widget.groupId);
      final userRef = db.collection('users').doc(memberId);
      batch.update(groupRef, {
        'members': FieldValue.arrayUnion([memberId]),
        'pendingRequests': FieldValue.arrayRemove([memberId]),
      });
      batch.update(userRef, {
        'joinedGroups': FieldValue.arrayUnion([widget.groupId]),
      });
      await batch.commit();
      _fetchGroupAndUserData();
    } catch (e) {
      _handleError("Error accepting member", e);
      if (mounted)
        setState(() {
          _isLoadingGroupData = false;
        });
    }
  }

  Future<void> _denyMember(String memberId) async {
    /* ... (unchanged) ... */
    if (!_isCurrentUserGroupCaretaker) return;
    setState(() {
      _isLoadingGroupData = true;
    });
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .update({
            'pendingRequests': FieldValue.arrayRemove([memberId]),
          });
      _fetchGroupAndUserData();
    } catch (e) {
      _handleError("Error denying member", e);
      if (mounted)
        setState(() {
          _isLoadingGroupData = false;
        });
    }
  }

  void _handleError(String contextMessage, dynamic error) {
    /* ... (unchanged) ... */
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
    // ... (Build method remains unchanged, including centered QR code and fancy member list) ...
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: Text(_groupName ?? 'ตั้งค่ากลุ่ม')),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),
            if (_isLoadingGroupData &&
                _pendingMembersData.isEmpty &&
                _membersData.isEmpty)
              const Center(child: CircularProgressIndicator())
            else
              RefreshIndicator(
                onRefresh: _fetchGroupAndUserData,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            if (_isCurrentUserGroupCaretaker)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Material(
                                  color: Theme.of(context).primaryColor,
                                  shape: const CircleBorder(),
                                  elevation: 2.0,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _showImagePickerOptions,
                                    child: Container(
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
                                              child: CircularProgressIndicator(
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
                      _buildInfoSection(
                        label: 'ชื่อกลุ่ม',
                        value: _groupName ?? '...',
                        onEdit: _isCurrentUserGroupCaretaker
                            ? () =>
                                  _showEditDialog('groupName', _groupName ?? '')
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

                      // --- Pending Requests Section ---
                      if (_isCurrentUserGroupCaretaker &&
                          _pendingMembersData.isNotEmpty) ...[
                        _buildPendingRequestsList(screenWidth),
                        const SizedBox(height: 24),
                      ],

                      if (_isCurrentUserGroupCaretaker) ...[
                        Center(child: _buildInviteCodeSection(screenWidth)),
                        const SizedBox(height: 24),
                      ],

                      _buildMembersList(screenWidth),
                      const SizedBox(height: 24),

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
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            if (_isLoadingGroupData &&
                (_pendingMembersData.isNotEmpty || _membersData.isNotEmpty))
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: Theme.of(context).primaryColor,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoSection({
    required String label,
    required String value,
    required double screenWidth,
    Color? valueColor,
    VoidCallback? onEdit,
  }) {
    /* ... (unchanged) ... */
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
          if (onEdit != null)
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
    /* ... (unchanged) ... */
    if (_inviteCode == null) return const SizedBox.shrink();
    return Container(
      width: screenWidth * 0.8,
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
            size: screenWidth * 0.45,
          ),
          const SizedBox(height: 16),
          SelectableText(
            _inviteCode!,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: screenWidth * 0.07,
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

  // --- Pending Requests List ---
  Widget _buildPendingRequestsList(double screenWidth) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.yellow.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'คำขอเข้าร่วม (${_pendingMembersData.length})',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.05,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _pendingMembersData.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.orange.shade100),
            itemBuilder: (context, index) {
              final member = _pendingMembersData[index];
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
                subtitle: _buildFancyRole(member['role'] == 'caretaker'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.red.shade400),
                      tooltip: 'ปฏิเสธ',
                      onPressed: () => _denyMember(member['uid']),
                    ),
                    IconButton(
                      icon: Icon(Icons.check, color: Colors.green.shade600),
                      tooltip: 'อนุมัติ',
                      onPressed: () => _acceptMember(member['uid']),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Members List (with kick button) ---
  Widget _buildMembersList(double screenWidth) {
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
          const SizedBox(height: 8),
          if (_membersData.isEmpty)
            const Text(
              'ยังไม่มีสมาชิกอื่น',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                color: Colors.grey,
              ),
            ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _membersData.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              final member = _membersData[index];
              final isCaretaker = member['role'] == 'caretaker';
              final profilePicUrl = member['profilePicUrl'] as String?;
              final bool isSelf = member['uid'] == _currentUserId;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 4.0),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage:
                      (profilePicUrl != null && profilePicUrl.isNotEmpty)
                      ? NetworkImage(profilePicUrl)
                      : null,
                  child: (profilePicUrl == null || profilePicUrl.isEmpty)
                      ? Icon(
                          Icons.person,
                          size: 22,
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
                subtitle: _buildFancyRole(isCaretaker),
                trailing: (_isCurrentUserGroupCaretaker && !isSelf)
                    ? IconButton(
                        icon: Icon(
                          Icons.remove_circle_outline,
                          color: Colors.red[300],
                        ),
                        tooltip: 'นำสมาชิกออก',
                        onPressed: () => _showRemoveMemberDialog(
                          member['uid'],
                          member['username'],
                        ),
                      )
                    : null,
              );
            },
          ),
        ],
      ),
    );
  }

  // --- Fancy Role Widget ---
  Widget _buildFancyRole(bool isCaretaker) {
    final Color color = isCaretaker
        ? const Color(0xFF2E88F3)
        : const Color(0xFF7ED6A8); // Blue or Green
    final IconData icon = isCaretaker
        ? Icons.admin_panel_settings_outlined
        : Icons.person_outline;
    final String text = isCaretaker ? 'ผู้ดูแล' : 'ผู้รับการดูแล';

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
} // End of _GroupSettingsScreenState
