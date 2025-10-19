// lib/screens/groups_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './login_screen.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import './home_screen.dart';
import './settings_screen.dart';
import './create_group_screen.dart';
import './join_group_screen.dart';
import './group_detail_screen.dart'; // <-- Make sure this is imported

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  int _selectedIndex = 0;
  String? _userRole;
  bool _isLoading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    _currentUser = _auth.currentUser;
    if (_currentUser == null) {
      _logout();
      return;
    }

    try {
      final userDoc = await _db
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          _userRole = userDoc.data()?['role'];
          _isLoading = false;
        });
      } else {
        _logout();
      }
    } catch (e) {
      print('Error fetching user data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _logout() {
    _auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);

    if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
      );
    }
  }

  void _showCreateJoinDialog() {
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
                'กลุ่ม',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // --- This is the Role-Aware Row ---
              Row(
                mainAxisAlignment: _userRole == 'caretaker'
                    ? MainAxisAlignment.spaceEvenly
                    : MainAxisAlignment.center,
                children: [
                  if (_userRole == 'caretaker')
                    _buildGroupOption(
                      icon: Icons.add,
                      label: 'สร้างกลุ่ม',
                      onTap: () {
                        Navigator.pop(context);
                        _createGroup();
                      },
                    ),
                  _buildGroupOption(
                    icon: Icons.group_add,
                    label: 'เข้าร่วมกลุ่ม',
                    onTap: () {
                      Navigator.pop(context);
                      _joinGroup();
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

  Widget _buildGroupOption({
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

  void _createGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
    );
  }

  void _joinGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JoinGroupScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: screenWidth * 0.06,
                right: screenWidth * 0.06,
                top: screenHeight * 0.02,
                bottom: 100,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'กลุ่ม',
                        style: TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: screenWidth * 0.08,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2E88F3),
                        ),
                      ),
                      // Role-aware "Add" button
                      GestureDetector(
                        onTap: _showCreateJoinDialog,
                        child: Container(
                          width: screenWidth * 0.12,
                          height: screenWidth * 0.12,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E88F3),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.add,
                            size: screenWidth * 0.06,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.04),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildGroupStream(screenWidth, screenHeight),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildGroupStream(double screenWidth, double screenHeight) {
    if (_currentUser == null) {
      return _buildEmptyState(screenWidth, screenHeight);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('groups')
          .where('members', arrayContains: _currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          print("Firestore Error: ${snapshot.error}");
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(screenWidth, screenHeight);
        }
        final groupDocs = snapshot.data!.docs;
        return _buildGroupsList(groupDocs);
      },
    );
  }

  Widget _buildGroupsList(List<QueryDocumentSnapshot> groupDocs) {
    return ListView.builder(
      itemCount: groupDocs.length,
      itemBuilder: (context, index) {
        // Get the data from the Firestore document
        final group = groupDocs[index].data() as Map<String, dynamic>;
        final groupId = groupDocs[index].id; // Get group ID for navigation

        // Use default values if fields are missing
        final groupName = group['groupName'] ?? 'ไม่มีชื่อกลุ่ม';
        final groupDesc = group['description'] ?? 'ไม่มีคำอธิบาย';
        final memberCount = (group['members'] as List?)?.length ?? 0;
        final groupImageUrl =
            group['groupImageUrl'] as String?; // <-- Get the image URL

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Navigate to detail screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupDetailScreen(
                      groupId: groupId,
                      groupName: groupName,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // --- UPDATED Group Image ---
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: ClipRRect(
                        // Use ClipRRect for rounded corners
                        borderRadius: BorderRadius.circular(12),
                        child:
                            (groupImageUrl != null && groupImageUrl.isNotEmpty)
                            ? Image.network(
                                // Display network image if URL exists
                                groupImageUrl,
                                fit: BoxFit.cover,
                                // Optional: Add loading/error builders for better UX
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          value:
                                              loadingProgress
                                                      .expectedTotalBytes !=
                                                  null
                                              ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                              : null,
                                        ),
                                      );
                                    },
                                errorBuilder: (context, error, stackTrace) {
                                  print(
                                    "Error loading group image: $error",
                                  ); // Log error
                                  return _buildFallbackGroupIcon(); // Show placeholder on error
                                },
                              )
                            : _buildFallbackGroupIcon(), // Show placeholder if no URL
                      ),
                    ),

                    // --- END UPDATED ---
                    const SizedBox(width: 16),
                    // Group info (unchanged)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupName,
                            style: const TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            groupDesc,
                            style: const TextStyle(
                              fontFamily: 'NotoLoopedThaiUI',
                              fontSize: 14,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines:
                                1, // Prevent long descriptions overflowing
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.people_outline, // Slightly different icon
                                size: 16,
                                color: const Color(0xFF9CA3AF),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$memberCount สมาชิก',
                                style: const TextStyle(
                                  fontFamily: 'NotoLoopedThaiUI',
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: const Color(0xFF9CA3AF),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- NEW Helper Widget for Fallback Icon ---
  Widget _buildFallbackGroupIcon() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7ED6A8).withOpacity(0.2), // Use a theme color
        // borderRadius: BorderRadius.circular(12), // Already handled by ClipRRect
      ),
      child: Icon(
        Icons.group_outlined, // Use outlined icon
        size: 30,
        color: const Color(0xFF7ED6A8).withOpacity(0.8),
      ),
    );
  }

  Widget _buildEmptyState(double screenWidth, double screenHeight) {
    final bool isCaretaker = _userRole == 'caretaker';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: screenWidth * 0.3,
            height: screenWidth * 0.3,
            decoration: BoxDecoration(
              color: const Color(0xFF2E88F3).withOpacity(0.1),
              borderRadius: BorderRadius.circular(screenWidth * 0.15),
            ),
            child: Icon(
              Icons.group,
              size: screenWidth * 0.15,
              color: const Color(0xFF2E88F3).withOpacity(0.5),
            ),
          ),
          SizedBox(height: screenHeight * 0.03),
          Text(
            'ยังไม่มีกลุ่ม',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF374151),
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.1),
            child: Text(
              isCaretaker
                  ? 'สร้างกลุ่มใหม่หรือเข้าร่วมกลุ่มที่มีอยู่\nเพื่อแชร์การดูแลร่วมกัน'
                  : 'ขอให้ผู้ดูแลของคุณเชิญคุณเข้าร่วมกลุ่ม\nโดยใช้รหัสเข้าร่วม',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: screenWidth * 0.04,
                color: const Color(0xFF6B7280),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: screenHeight * 0.04),

          // --- This is the Role-Aware Button logic ---
          if (isCaretaker)
            GestureDetector(
              onTap: _showCreateJoinDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E88F3),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'เริ่มต้นใช้งาน',
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (!isCaretaker)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const JoinGroupScreen(),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7ED6A8),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.group_add, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'เข้าร่วมกลุ่ม',
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: screenWidth * 0.04,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
