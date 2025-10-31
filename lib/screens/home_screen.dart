// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/notification_service.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import '../widgets/custom_fade_route.dart';
import './groups_screen.dart';
import './settings_screen.dart';
import './login_screen.dart';
// Removed GroupDetailScreen import as it's not directly needed here

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1;
  String? _username;
  String? _userRole;
  String? _profilePicUrl; // Added for profile picture
  bool _isLoading = true;

  // Caches
  final Map<String, String> _userNameCache = {};
  final Map<String, String> _groupNameCache = {};

  final NotificationService _notificationService = NotificationService();

  final Map<String, Color> dayColors = {
    'วันจันทร์': Colors.yellow.shade700,
    'วันอังคาร': Colors.pink.shade400,
    'วันพุธ': Colors.green.shade500,
    'วันพฤหัสบดี': Colors.orange.shade600,
    'วันศุกร์': Colors.blue.shade500, // Corrected key
    'วันเสาร์': Colors.purple.shade400,
    'วันอาทิตย์': Colors.red.shade500,
  };
  final List<String> _dayLabelsShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  // Consistent Task Type Colors
  final Color _appointmentColor = const Color(0xFF2E88F3); // Blue
  final Color _countdownColor = const Color(0xFF7ED6A8); // Green
  final Color _habitColor = Colors.purple.shade300; // Purple
  final Color _completedColor = Colors.green.shade600; // Completed Green
  final Color _overdueColor = Colors.red.shade400; // Overdue Red
  final Color _pendingColor = Colors.orange.shade600; // Pending Orange
  final Color _todayEventColor = Colors.teal.shade400; // Today Event Teal

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('th', null);
    _fetchUserData();
  }

  // --- Data Fetching and Helpers ---
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logout();
      return;
    }
    try {
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _username = userDoc.data()?['username'];
          _userRole = userDoc.data()?['role'];
          _profilePicUrl = userDoc.data()?['profilePicUrl'];
          _isLoading = false;
        });
      } else {
        _logout();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, String>> _getUsernames(List<String> userIds) async {
    Map<String, String> names = {};
    List<String> idsToFetch = [];
    for (String id in userIds.toSet()) {
      if (!_userNameCache.containsKey(id) && id.isNotEmpty) {
        idsToFetch.add(id);
      } else if (_userNameCache.containsKey(id)) {
        names[id] = _userNameCache[id]!;
      }
    }
    if (idsToFetch.isNotEmpty) {
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
          // Create a map of found user data
          final Map<String, Map<String, dynamic>> foundUsers = {
            for (var doc in querySnapshot.docs) doc.id: doc.data(),
          };

          // Iterate through the IDs we tried to fetch
          for (String idInBatch in batchIds) {
            if (foundUsers.containsKey(idInBatch)) {
              // User exists
              final data = foundUsers[idInBatch]!;
              final name = data['username'] ?? 'Unknown User';
              _userNameCache[idInBatch] = name;
              names[idInBatch] = name;
            } else {
              // User does not exist (deleted)
              const name = 'ผู้ใช้ที่ถูกลบ'; // Thai for "Deleted User"
              _userNameCache[idInBatch] = name;
              names[idInBatch] = name;
            }
          }
          for (var doc in querySnapshot.docs) {
            final name = doc.data()['username'] ?? 'ไม่ทราบชื่อ';
            _userNameCache[doc.id] = name;
            names[doc.id] = name;
          }
        }
      } catch (e) {
        // Ignore individual fetch errors
      }
    }
    for (String id in userIds) {
      names.putIfAbsent(id, () => _userNameCache[id] ?? 'ไม่ทราบชื่อ');
    }
    return names;
  }

  final Map<String, Map<String, String?>> _groupDataCache =
      {}; // New: Stores {'name': '...', 'imageUrl': '...'}

  Future<void> _getGroupNames(List<String> groupIds) async {
    List<String> idsToFetch = [];
    for (String id in groupIds.toSet()) {
      if (!_groupDataCache.containsKey(id) && id.isNotEmpty) {
        // Check new cache
        idsToFetch.add(id);
      }
    }
    if (idsToFetch.isNotEmpty) {
      try {
        for (var i = 0; i < idsToFetch.length; i += 10) {
          var batchIds = idsToFetch.sublist(
            i,
            i + 10 > idsToFetch.length ? idsToFetch.length : i + 10,
          );
          if (batchIds.isEmpty) continue;
          final querySnapshot = await FirebaseFirestore.instance
              .collection('groups')
              .where(FieldPath.documentId, whereIn: batchIds)
              .get();
          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            final name = data['groupName'] ?? 'กลุ่มไม่มีชื่อ';
            final imageUrl = data['groupImageUrl'] as String?; // Get image URL
            _groupDataCache[doc.id] = {
              'name': name,
              'imageUrl': imageUrl,
            }; // Store both
          }
        }
      } catch (e) {
        // Ignore fetch errors
      }
    }
    // Ensure default entries exist even if fetch failed partially
    for (String id in groupIds) {
      _groupDataCache.putIfAbsent(
        id,
        () => {'name': 'กลุ่มไม่มีชื่อ', 'imageUrl': null},
      );
    }
    if (idsToFetch.isNotEmpty && mounted) {
      setState(() {}); // Trigger rebuild after fetching
    }
  }

  // --- NEW HELPER ---
  /// Parses a "HH:mm" time string into a DateTime object for a given day.
  DateTime? _parseTimeString(String timeStr, DateTime today) {
    try {
      final parts = timeStr.split(':');
      if (parts.length != 2) return null;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) return null;
      return DateTime(today.year, today.month, today.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  void _logout() {
    FirebaseAuth.instance.signOut();
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

    if (index == 0) {
      Navigator.pushReplacement(
        context,
        FadeRoute(child: const GroupsScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        FadeRoute(child: const SettingsScreen()),
      );
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
    final today = DateTime.now();
    final thaiWeekdayName = DateFormat(
      'EEEE',
      'th',
    ).format(today); // e.g., "วันเสาร์"
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
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Padding(
                padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: screenHeight * 0.02),
                    _buildHeader(screenWidth),
                    SizedBox(height: screenHeight * 0.01),
                    _buildTodayLabel(thaiWeekdayName, today, screenWidth),
                    SizedBox(height: screenHeight * 0.02),
                    if (_userRole == 'caretaker')
                      _buildCaretakerContent(screenWidth)
                    else if (_userRole == 'carereceiver')
                      _buildCareReceiverContent(screenWidth)
                    else
                      const Expanded(
                        child: Center(child: Text('ไม่พบบทบาทผู้ใช้งาน')),
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

  Widget _buildHeader(double screenWidth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สวัสดีจ้า',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: screenWidth * 0.06,
                color: const Color(0xFF6B7280),
              ),
            ),
            Text(
              _username ?? 'ผู้ใช้งาน',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: screenWidth * 0.08,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E88F3),
              ),
            ),
          ],
        ),
        // Updated Avatar
        CircleAvatar(
          radius: screenWidth * 0.06,
          backgroundColor: Colors.grey.shade200,
          backgroundImage:
              (_profilePicUrl != null && _profilePicUrl!.isNotEmpty)
              ? NetworkImage(_profilePicUrl!)
              : null,
          child: (_profilePicUrl == null || _profilePicUrl!.isEmpty)
              ? Icon(
                  Icons.person,
                  size: screenWidth * 0.06,
                  color: Colors.grey.shade400,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildTodayLabel(
    String thaiWeekdayName,
    DateTime today,
    double screenWidth,
  ) {
    // Format the date part: e.g., "26 ตุลาคม 2025"
    final formattedDate = DateFormat('d MMMM y', 'th').format(today);
    // Get the color for the capsule background
    final Color dayColor =
        dayColors[thaiWeekdayName] ?? Colors.grey; // Fallback color
    // Combine "Today" and the day name
    final String capsuleText =
        'วันนี้ $thaiWeekdayName'; // e.g., "วันนี้ วันอาทิตย์"

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Day name capsule (now includes "วันนี้")
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 1.0,
            ), // Padding inside capsule
            decoration: BoxDecoration(
              color: dayColor, // Use the day's specific color
              borderRadius: BorderRadius.circular(
                20.0,
              ), // Make it capsule-shaped
            ),
            child: Text(
              capsuleText, // Use the combined string
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: screenWidth * 0.05, // Adjust size if needed
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text inside capsule
              ),
            ),
          ),
          // Date part (follows the capsule)
          Text(
            ' $formattedDate', // e.g., " 26 ตุลาคม 2025" (note the leading space)
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.055,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700], // Default text color for the date part
            ),
          ),
        ],
      ),
    );
  }

  // --- Content for Caretakers (Grouped Dashboard) ---
  Widget _buildCaretakerContent(double screenWidth) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Expanded(child: Center(child: Text('ไม่พบผู้ใช้งาน')));
    }

    return Expanded(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<String> joinedGroups =
              (userData['joinedGroups'] as List?)?.cast<String>() ?? [];
          if (joinedGroups.isEmpty) return _buildEmptyTaskList(screenWidth);

          _getGroupNames(joinedGroups); // Pre-fetch group names

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('tasks')
                .where('groupId', whereIn: joinedGroups)
                .snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (taskSnapshot.hasError) {
                // Print error object to console
                // print("!!!!!!!! HOME SCREEN STREAM ERROR !!!!!!!");
                // print(taskSnapshot.error);
                // print(taskSnapshot.stackTrace); // Also print the stack trace
                return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดงาน'));
              }
              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty) {
                return _buildEmptyTaskList(screenWidth);
              }

              final allTasks = taskSnapshot.data!.docs;
              final now = DateTime.now(); // <-- Has time
              final today = DateTime(now.year, now.month, now.day); // Date only
              final todayKey = DateFormat('yyyy-MM-dd').format(today);
              final todayWeekday = today.weekday;

              // --- Process, Group, and Categorize Tasks ---
              final Map<String, Map<String, List<Map<String, dynamic>>>>
              groupedCategorizedTasks = {};
              final Set<String> usersToFetch = {};

              for (var doc in allTasks) {
                final task = doc.data() as Map<String, dynamic>?;
                if (task == null) continue;
                final groupId = task['groupId'] as String?;
                if (groupId == null || groupId.isEmpty) continue;
                final type = task['taskType'] ?? '';
                final status = task['status'] ?? '';
                final assignedTo =
                    (task['assignedTo'] as List?)?.cast<String>() ?? [];
                usersToFetch.addAll(assignedTo);
                final completedBy = task['completedBy'] as String?;
                if (completedBy != null) usersToFetch.add(completedBy);
                groupedCategorizedTasks.putIfAbsent(
                  groupId,
                  () => {
                    'pending_today': [],
                    'overdue_today': [], // <-- NEW
                    'completed_today': [],
                    'todays_countdowns': [], // <-- NEW
                    'habits': [],
                    'upcoming': [],
                  },
                );
                final Timestamp? ts = task['taskDateTime'];
                DateTime? taskDate; // Has time
                DateTime? taskDayOnly; // Date only
                if (ts != null) {
                  taskDate = ts.toDate();
                  taskDayOnly = DateTime(
                    taskDate.year,
                    taskDate.month,
                    taskDate.day,
                  );
                }
                bool isToday =
                    taskDayOnly != null && taskDayOnly.isAtSameMomentAs(today);

                if (type == 'habit_schedule') {
                  groupedCategorizedTasks[groupId]!['habits']!.add({
                    'id': doc.id,
                    'data': task,
                  });
                  // Extract today's items
                  final schedule =
                      (task['schedule'] as Map?)
                          ?.cast<String, List<dynamic>>() ??
                      {};
                  final tasksForTodayDynamic =
                      schedule[todayWeekday.toString()];
                  if (tasksForTodayDynamic != null) {
                    final List<Map<String, String>> tasksForToday =
                        tasksForTodayDynamic
                            .cast<Map<dynamic, dynamic>>()
                            .map((item) => item.cast<String, String>())
                            .toList();
                    final completionHistory =
                        (task['completionHistory'] as Map?)
                            ?.cast<String, String>() ??
                        {};
                    for (var subTask in tasksForToday) {
                      final subTaskTimeStr = subTask['time'] ?? '';
                      final subTaskTitle = subTask['title'] ?? '';
                      final subTaskKey =
                          '${todayKey}_${subTaskTimeStr}_$subTaskTitle';
                      final isCompleted =
                          completionHistory[subTaskKey] == 'completed';

                      final itemData = {
                        'type': 'habit_item',
                        'id': doc.id,
                        'groupId': groupId,
                        'subTaskKey': subTaskKey,
                        'time': subTaskTimeStr,
                        'title': subTaskTitle,
                        'assignedTo': assignedTo,
                        'isCompleted': isCompleted,
                        'data': task,
                      };

                      if (isCompleted) {
                        groupedCategorizedTasks[groupId]!['completed_today']!
                            .add(itemData);
                      } else {
                        // Check if overdue
                        final subTaskDateTime = _parseTimeString(
                          subTaskTimeStr,
                          today,
                        );
                        if (subTaskDateTime != null &&
                            subTaskDateTime.isBefore(now)) {
                          groupedCategorizedTasks[groupId]!['overdue_today']!
                              .add(itemData);
                        } else {
                          groupedCategorizedTasks[groupId]!['pending_today']!
                              .add(itemData);
                        }
                      }
                    }
                  }
                } else if (type == 'appointment') {
                  if (isToday) {
                    if (status == 'completed') {
                      groupedCategorizedTasks[groupId]!['completed_today']!
                          .add({
                            'type': 'appointment',
                            'id': doc.id,
                            'groupId': groupId,
                            'data': task,
                            'isCompleted': true,
                          });
                    } else if (taskDate != null && taskDate.isBefore(now)) {
                      // Today but time has passed
                      groupedCategorizedTasks[groupId]!['overdue_today']!.add({
                        'type': 'appointment',
                        'id': doc.id,
                        'groupId': groupId,
                        'data': task,
                        'isCompleted': false,
                      });
                    } else {
                      // Today but time has not passed
                      groupedCategorizedTasks[groupId]!['pending_today']!.add({
                        'type': 'appointment',
                        'id': doc.id,
                        'groupId': groupId,
                        'data': task,
                        'isCompleted': false,
                      });
                    }
                  } else if (taskDate != null && taskDate.isAfter(today)) {
                    // Future appointment
                    groupedCategorizedTasks[groupId]!['upcoming']!.add({
                      'type': 'appointment',
                      'id': doc.id,
                      'groupId': groupId,
                      'data': task,
                    });
                  } else if (taskDate != null &&
                      taskDate.isBefore(today) &&
                      status == 'pending') {
                    // Overdue from *previous* days
                    groupedCategorizedTasks[groupId]!['overdue_today']!.add({
                      'type': 'appointment',
                      'id': doc.id,
                      'groupId': groupId,
                      'data': task,
                      'isCompleted': false,
                    });
                  }
                } else if (type == 'countdown') {
                  if (taskDate == null) continue;
                  final int days = taskDayOnly!.difference(today).inDays;
                  final itemData = {
                    // <-- Create itemData once
                    'type': 'countdown',
                    'id': doc.id,
                    'groupId': groupId,
                    'data': task,
                  };
                  if (days == 0) {
                    groupedCategorizedTasks[groupId]!['todays_countdowns']!.add(
                      itemData,
                    );
                  } else if (days > 0) {
                    groupedCategorizedTasks[groupId]!['upcoming']!.add(
                      itemData,
                    );
                  } else if (days < 0) {
                    // <-- ADD THIS
                    groupedCategorizedTasks[groupId]!['overdue_today']!.add(
                      itemData,
                    );
                  }
                }
              }

              _getUsernames(usersToFetch.toList()); // Fetch names

              // Sort items within categories for each group
              groupedCategorizedTasks.forEach((groupId, categories) {
                categories['pending_today']?.sort(_sortTaskItems);
                categories['overdue_today']?.sort(
                  _sortTaskItems,
                ); // Sort new list
                categories['completed_today']?.sort(_sortCompletedItems);
                categories['todays_countdowns']?.sort(
                  _sortUpcomingItems,
                ); // Sort new list
                categories['upcoming']?.sort(_sortUpcomingItems);
                categories['habits']?.sort(
                  (a, b) => (a['data']['title'] ?? '').compareTo(
                    b['data']['title'] ?? '',
                  ),
                );
              });

              // Sort groups by name
              final sortedGroupIds = groupedCategorizedTasks.keys.toList()
                ..sort(
                  (a, b) => (_groupNameCache[a] ?? 'Z').compareTo(
                    _groupNameCache[b] ?? 'Z',
                  ),
                );

              // Filter out groups with no relevant tasks
              final relevantGroupIds = sortedGroupIds.where((groupId) {
                final categories = groupedCategorizedTasks[groupId]!;
                return categories['pending_today']!.isNotEmpty ||
                    categories['overdue_today']!.isNotEmpty ||
                    categories['completed_today']!.isNotEmpty ||
                    categories['todays_countdowns']!.isNotEmpty ||
                    categories['habits']!.isNotEmpty ||
                    categories['upcoming']!.isNotEmpty;
              }).toList();

              if (relevantGroupIds.isEmpty) {
                return _buildEmptyTaskList(screenWidth);
              }

              // --- Build Grouped ListView ---
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: relevantGroupIds.length,
                itemBuilder: (context, index) {
                  final groupId = relevantGroupIds[index];
                  final groupData =
                      _groupDataCache[groupId] ??
                      {'name': 'Loading...', 'imageUrl': null};
                  final groupName = groupData['name'] ?? 'Loading...';
                  final groupImageUrl = groupData['imageUrl']; // Get the URL
                  final categories = groupedCategorizedTasks[groupId]!;
                  final pendingToday = categories['pending_today']!;
                  final overdueToday = categories['overdue_today']!; // New
                  final completedToday = categories['completed_today']!;
                  final todaysCountdowns =
                      categories['todays_countdowns']!; // New
                  final habits = categories['habits']!;
                  final upcoming = categories['upcoming']!;

                  // --- UI CHANGE: Wrap sections in a Card ---
                  return Card(
                    elevation: 2.0,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Row(
                            // Wrap in a Row
                            children: [
                              // Group Image Avatar
                              CircleAvatar(
                                radius:
                                    screenWidth * 0.05, // Adjust size as needed
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    (groupImageUrl != null &&
                                        groupImageUrl.isNotEmpty)
                                    ? NetworkImage(groupImageUrl)
                                    : null,
                                child:
                                    (groupImageUrl == null ||
                                        groupImageUrl.isEmpty)
                                    ? Icon(
                                        // Fallback icon
                                        Icons.home,
                                        size: screenWidth * 0.05,
                                        color: Colors.grey.shade500,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12), // Spacing
                              // Group Name Text (Expanded to fill remaining space)
                              Expanded(
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontFamily: 'NotoLoopedThaiUI',
                                    fontSize:
                                        screenWidth *
                                        0.055, // Or receiver's 0.05
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Colors.black87, // Or receiver's black54
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis, // Prevent overflow
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sections for this group
                        if (pendingToday.isNotEmpty) ...[
                          _buildSectionHeader(
                            'วันนี้ (รอดำเนินการ)',
                            Icons.radio_button_unchecked,
                            _pendingColor,
                            screenWidth,
                          ),
                          ...pendingToday.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildDashboardItemCard(item, screenWidth),
                            ),
                          ),
                        ],
                        if (overdueToday.isNotEmpty) ...[
                          _buildSectionHeader(
                            'ผ่านไปแล้ว',
                            Icons.warning_amber_rounded,
                            _overdueColor,
                            screenWidth,
                          ),
                          ...overdueToday.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildDashboardItemCard(item, screenWidth),
                            ),
                          ),
                        ],
                        if (completedToday.isNotEmpty) ...[
                          _buildSectionHeader(
                            'วันนี้ (เสร็จสิ้น)',
                            Icons.check_circle,
                            _completedColor,
                            screenWidth,
                          ),
                          ...completedToday.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildDashboardItemCard(
                                item,
                                screenWidth,
                                isCompleted: true,
                              ),
                            ),
                          ),
                        ],
                        if (todaysCountdowns.isNotEmpty) ...[
                          _buildSectionHeader(
                            'กิจกรรมวันนี้!',
                            Icons.celebration_rounded,
                            _todayEventColor,
                            screenWidth,
                          ),
                          ...todaysCountdowns.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildCountdownCard(
                                item['data'],
                                screenWidth,
                              ),
                            ),
                          ),
                        ],
                        if (habits.isNotEmpty) ...[
                          _buildSectionHeader(
                            'กิจวัตรที่ใช้งานอยู่',
                            Icons.calendar_month,
                            _habitColor,
                            screenWidth,
                          ),
                          ...habits.map((item) {
                            // Construct the data map needed by the modal
                            final itemDataForModal = {
                              'type': 'habit_schedule',
                              'data': item['data'],
                              'id': item['id'],
                              'groupId':
                                  item['data']['groupId'] ??
                                  '', // Ensure groupId is included
                            };
                            return InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                itemDataForModal,
                              ),
                              child: _buildHabitScheduleSummaryCard(
                                item['data'],
                                screenWidth,
                              ),
                            );
                          }),
                        ],
                        if (upcoming.isNotEmpty) ...[
                          _buildSectionHeader(
                            'สิ่งที่กำลังจะมาถึง',
                            Icons.hourglass_bottom,
                            Colors.grey.shade600,
                            screenWidth,
                          ),
                          ...upcoming.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: item['type'] == 'countdown'
                                  ? _buildCountdownCard(
                                      item['data'],
                                      screenWidth,
                                    )
                                  : _buildAppointmentCardReadOnly(
                                      item['data'],
                                      screenWidth,
                                    ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10), // Padding at card bottom
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- Content for Care Receivers (Grouped & Categorized) ---
  Widget _buildCareReceiverContent(double screenWidth) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Expanded(child: Center(child: Text('ไม่พบผู้ใช้งาน')));
    }

    return Expanded(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));
          }

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<String> joinedGroups =
              (userData['joinedGroups'] as List?)?.cast<String>() ?? [];
          if (joinedGroups.isEmpty) return _buildEmptyTaskList(screenWidth);

          _getGroupNames(joinedGroups); // Pre-fetch names

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('tasks')
                // Add filter for relevant tasks
                .where('groupId', whereIn: joinedGroups)
                .snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (taskSnapshot.hasError) {
                // Print error object to the console
                // print("!!!!!!!! HOME SCREEN STREAM ERROR !!!!!!!");
                // print(taskSnapshot.error);
                // print(taskSnapshot.stackTrace); // Also print the stack trace
                return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดงาน'));
              }
              if (!taskSnapshot.hasData ||
                  taskSnapshot.data == null ||
                  taskSnapshot.data!.docs.isEmpty) {
                return _buildEmptyTaskList(screenWidth);
              }

              final allTasks = taskSnapshot.data!.docs;

              // Schedule all notifications for the user
              _scheduleReceiverNotifications(allTasks, user.uid);

              final now = DateTime.now(); // <-- Has time
              final today = DateTime(now.year, now.month, now.day); // Date only
              final todayKey = DateFormat('yyyy-MM-dd').format(today);
              final todayWeekday = today.weekday;

              // --- Process, Group, and Filter Tasks for CareReceiver ---
              final Map<String, Map<String, List<Map<String, dynamic>>>>
              groupedCategorizedTasks = {};

              for (var doc in allTasks) {
                final task = doc.data() as Map<String, dynamic>?;
                if (task == null) continue;
                final groupId = task['groupId'] as String?;
                if (groupId == null || groupId.isEmpty) continue;
                final type = task['taskType'] ?? '';
                final status = task['status'] ?? '';
                final assignedTo =
                    (task['assignedTo'] as List?)?.cast<String>() ?? [];

                // --- Universal relevance check ---
                bool relevantToUser = false;
                if (type == 'countdown') {
                  relevantToUser = true; // Countdowns are for everyone
                } else if (assignedTo.contains(user.uid)) {
                  relevantToUser = true; // Assigned to this user
                }
                if (!relevantToUser) continue; // Skip task if not relevant
                // --- End check ---

                // Initialize group map
                groupedCategorizedTasks.putIfAbsent(
                  groupId,
                  () => {
                    'pending_habits': [],
                    'pending_appointments': [],
                    'overdue_habits': [], // <-- NEW
                    'overdue_appointments': [], // <-- NEW
                    'overdue_countdowns': [],
                    'completed_today': [], // <-- NEW
                    'todays_countdowns': [], // <-- NEW
                    'upcoming_appointments': [], // <-- NEW
                    'upcoming_countdowns': [],
                  },
                );

                final Timestamp? ts = task['taskDateTime'];
                DateTime? taskDate; // Has time
                DateTime? taskDayOnly; // Date only
                if (ts != null) {
                  taskDate = ts.toDate();
                  taskDayOnly = DateTime(
                    taskDate.year,
                    taskDate.month,
                    taskDate.day,
                  );
                }
                bool isToday =
                    taskDayOnly != null && taskDayOnly.isAtSameMomentAs(today);

                // Categorize and Filter
                if (type == 'habit_schedule') {
                  final schedule =
                      (task['schedule'] as Map?)
                          ?.cast<String, List<dynamic>>() ??
                      {};
                  final tasksForTodayDynamic =
                      schedule[todayWeekday.toString()];
                  if (tasksForTodayDynamic != null &&
                      tasksForTodayDynamic.isNotEmpty) {
                    final List<Map<String, String>> tasksForToday =
                        tasksForTodayDynamic
                            .cast<Map<dynamic, dynamic>>()
                            .map((item) => item.cast<String, String>())
                            .toList();
                    final completionHistory =
                        (task['completionHistory'] as Map?)
                            ?.cast<String, String>() ??
                        {};
                    for (var i = 0; i < tasksForToday.length; i++) {
                      final subTask = tasksForToday[i];
                      final subTaskTimeStr = subTask['time'] ?? 'no_time_$i';
                      final subTaskTitle = subTask['title'] ?? 'no_title_$i';
                      final subTaskKey =
                          '${todayKey}_${subTaskTimeStr}_$subTaskTitle';
                      final isCompleted =
                          completionHistory[subTaskKey] == 'completed';

                      final itemData = {
                        'type': 'habit_item', // For card builder
                        'habitDocId': doc.id,
                        'groupId': groupId,
                        'subTaskKey': subTaskKey,
                        'time': subTaskTimeStr.startsWith('no_time')
                            ? '--:--'
                            : subTaskTimeStr,
                        'title': subTaskTitle.startsWith('no_title')
                            ? 'ไม่มีชื่อ'
                            : subTaskTitle,
                        'isCompleted': isCompleted,
                      };

                      if (isCompleted) {
                        groupedCategorizedTasks[groupId]!['completed_today']!
                            .add(itemData);
                      } else {
                        final subTaskDateTime = _parseTimeString(
                          subTaskTimeStr,
                          today,
                        );
                        if (subTaskDateTime != null &&
                            subTaskDateTime.isBefore(now)) {
                          groupedCategorizedTasks[groupId]!['overdue_habits']!
                              .add(itemData);
                        } else {
                          groupedCategorizedTasks[groupId]!['pending_habits']!
                              .add(itemData);
                        }
                      }
                    }
                  }
                } else if (type == 'appointment') {
                  final itemData = {
                    'type': 'appointment', // For card builder
                    'id': doc.id,
                    'data': task,
                    'isCompleted': status == 'completed',
                  };

                  if (isToday) {
                    if (status == 'completed') {
                      groupedCategorizedTasks[groupId]!['completed_today']!.add(
                        itemData,
                      );
                    } else if (taskDate != null && taskDate.isBefore(now)) {
                      groupedCategorizedTasks[groupId]!['overdue_appointments']!
                          .add(itemData);
                    } else {
                      groupedCategorizedTasks[groupId]!['pending_appointments']!
                          .add(itemData);
                    }
                  } else if (taskDate != null && taskDate.isAfter(today)) {
                    groupedCategorizedTasks[groupId]!['upcoming_appointments']!
                        .add(itemData);
                  } else if (taskDate != null &&
                      taskDate.isBefore(today) &&
                      status == 'pending') {
                    groupedCategorizedTasks[groupId]!['overdue_appointments']!
                        .add(itemData);
                  }
                } else if (type == 'countdown') {
                  if (taskDate == null) continue;
                  final int days = taskDayOnly!.difference(today).inDays;
                  final itemData = {
                    'id': doc.id,
                    'data': task,
                    'type': 'countdown',
                  };
                  if (days == 0) {
                    groupedCategorizedTasks[groupId]!['todays_countdowns']!.add(
                      itemData,
                    );
                  } else if (days > 0) {
                    groupedCategorizedTasks[groupId]!['upcoming_countdowns']!
                        .add(itemData);
                  } else if (days < 0) {
                    groupedCategorizedTasks[groupId]!['overdue_countdowns']!
                        .add(itemData);
                  }
                }
              }
              // --- End Grouping ---

              // Sort items within each group's categories
              groupedCategorizedTasks.forEach((key, categories) {
                categories['pending_habits']?.sort(
                  (a, b) => (a['time'] ?? '99').compareTo(b['time'] ?? '99'),
                );
                categories['overdue_habits']?.sort(
                  (a, b) => (a['time'] ?? '99').compareTo(b['time'] ?? '99'),
                );
                categories['pending_appointments']?.sort(
                  (a, b) =>
                      (a['data']['taskDateTime'] as Timestamp?)?.compareTo(
                        b['data']['taskDateTime'] as Timestamp? ??
                            Timestamp.now(),
                      ) ??
                      0,
                );
                categories['overdue_appointments']?.sort(
                  (a, b) =>
                      (a['data']['taskDateTime'] as Timestamp?)?.compareTo(
                        b['data']['taskDateTime'] as Timestamp? ??
                            Timestamp.now(),
                      ) ??
                      0,
                );
                categories['completed_today']?.sort(
                  _sortCompletedItems,
                ); // Use helper
                categories['todays_countdowns']?.sort(
                  _sortUpcomingItems,
                ); // Use helper
                categories['upcoming_appointments']?.sort(
                  _sortUpcomingItems,
                ); // Use helper
                categories['upcoming_countdowns']?.sort(
                  _sortUpcomingItems,
                ); // Use helper
              });

              // Sort groups by name
              final sortedGroupIds = groupedCategorizedTasks.keys.toList()
                ..sort(
                  (a, b) => (_groupNameCache[a] ?? 'Z').compareTo(
                    _groupNameCache[b] ?? 'Z',
                  ),
                );

              // Filter out groups with no relevant items for the receiver
              final relevantGroupIds = sortedGroupIds.where((groupId) {
                final categories = groupedCategorizedTasks[groupId]!;
                return categories['pending_habits']!.isNotEmpty ||
                    categories['pending_appointments']!.isNotEmpty ||
                    categories['overdue_habits']!.isNotEmpty ||
                    categories['overdue_appointments']!.isNotEmpty ||
                    categories['completed_today']!.isNotEmpty ||
                    categories['todays_countdowns']!.isNotEmpty ||
                    categories['upcoming_appointments']!.isNotEmpty ||
                    categories['upcoming_countdowns']!.isNotEmpty;
              }).toList();

              if (relevantGroupIds.isEmpty) {
                return _buildEmptyTaskList(screenWidth);
              }

              // --- Build Grouped ListView for CareReceiver ---
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: relevantGroupIds.length,
                itemBuilder: (context, index) {
                  final groupId = relevantGroupIds[index];
                  final groupData =
                      _groupDataCache[groupId] ??
                      {'name': 'Loading...', 'imageUrl': null};
                  final groupName = groupData['name'] ?? 'Loading...';
                  final groupImageUrl = groupData['imageUrl']; // Get the URL
                  final categories = groupedCategorizedTasks[groupId]!;
                  final pendingHabits = categories['pending_habits']!;
                  final pendingAppointments =
                      categories['pending_appointments']!;
                  final overdueHabits = categories['overdue_habits']!;
                  final overdueAppointments =
                      categories['overdue_appointments']!;
                  // final overdueCountdowns = categories['overdue_countdowns']!;
                  final completedToday = categories['completed_today']!;
                  final todaysCountdowns = categories['todays_countdowns']!;
                  final upcomingAppointments =
                      categories['upcoming_appointments']!;
                  final upcomingCountdowns = categories['upcoming_countdowns']!;

                  // Combine pending/overdue lists for simplicity
                  final allPending = [...pendingHabits, ...pendingAppointments]
                    ..sort(_sortTaskItems);
                  final allOverdue = [...overdueHabits, ...overdueAppointments]
                    ..sort(_sortTaskItems);
                  final allUpcoming = [
                    ...upcomingAppointments,
                    ...upcomingCountdowns,
                  ]..sort(_sortUpcomingItems);

                  return Card(
                    elevation: 2.0,
                    shadowColor: Colors.black.withValues(alpha: 0.08),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                          child: Row(
                            // Wrap in a Row
                            children: [
                              // Group Image Avatar
                              CircleAvatar(
                                radius:
                                    screenWidth * 0.05, // Adjust size as needed
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage:
                                    (groupImageUrl != null &&
                                        groupImageUrl.isNotEmpty)
                                    ? NetworkImage(groupImageUrl)
                                    : null,
                                child:
                                    (groupImageUrl == null ||
                                        groupImageUrl.isEmpty)
                                    ? Icon(
                                        // Fallback icon
                                        Icons.group,
                                        size: screenWidth * 0.05,
                                        color: Colors.grey.shade500,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12), // Spacing
                              // Group Name Text (Expanded to fill remaining space)
                              Expanded(
                                child: Text(
                                  groupName,
                                  style: TextStyle(
                                    fontFamily: 'NotoLoopedThaiUI',
                                    fontSize:
                                        screenWidth *
                                        0.055, // Or receiver's 0.05
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Colors.black87, // Or receiver's black54
                                  ),
                                  overflow:
                                      TextOverflow.ellipsis, // Prevent overflow
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Sections for this group
                        if (allPending.isNotEmpty) ...[
                          _buildSectionHeader(
                            'วันนี้ (รอดำเนินการ)',
                            Icons.radio_button_unchecked,
                            _pendingColor,
                            screenWidth,
                          ),
                          ...allPending.map((item) {
                            // Determine which card widget to build based on the item type
                            Widget cardWidget;
                            if (item['type'] == 'habit_item') {
                              cardWidget = _buildHabitItemCard(
                                item,
                                screenWidth,
                              ); //
                            } else {
                              // Assuming appointment
                              cardWidget = _buildAppointmentCard(
                                item['data'], //
                                item['id'], //
                                screenWidth,
                              );
                            }

                            // Return the InkWell wrapping the determined card widget
                            return InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Call the modal function
                              child: cardWidget, // Display the appropriate card
                            );
                          }),
                        ],
                        if (allOverdue.isNotEmpty) ...[
                          _buildSectionHeader(
                            'ผ่านไปแล้ว',
                            Icons.warning_amber_rounded,
                            _overdueColor,
                            screenWidth,
                          ),
                          ...allOverdue.map((item) {
                            // Determine which card widget to build
                            Widget cardWidget;
                            if (item['type'] == 'habit_item') {
                              cardWidget = _buildHabitItemCard(
                                item,
                                screenWidth,
                              ); //
                            } else if (item['type'] == 'appointment') {
                              cardWidget = _buildAppointmentCard(
                                item['data'], //
                                item['id'], //
                                screenWidth,
                              );
                            } else {
                              // Assuming countdown
                              cardWidget = _buildCountdownCard(
                                item['data'], //
                                screenWidth,
                              );
                            }

                            // Return the InkWell wrapping the determined card widget
                            return InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Call the modal function
                              child: cardWidget, // Display the appropriate card
                            );
                          }),
                        ],
                        if (completedToday.isNotEmpty) ...[
                          _buildSectionHeader(
                            'วันนี้ (เสร็จสิ้น)',
                            Icons.check_circle,
                            _completedColor,
                            screenWidth,
                          ),
                          ...completedToday.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildDashboardItemCard(
                                item,
                                screenWidth,
                                isCompleted: true,
                              ),
                            ),
                          ),
                        ],
                        if (todaysCountdowns.isNotEmpty) ...[
                          _buildSectionHeader(
                            'กิจกรรมวันนี้!',
                            Icons.celebration_rounded,
                            _todayEventColor,
                            screenWidth,
                          ),
                          ...todaysCountdowns.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child: _buildCountdownCard(
                                item['data'],
                                screenWidth,
                              ),
                            ),
                          ),
                        ],
                        if (allUpcoming.isNotEmpty) ...[
                          _buildSectionHeader(
                            'สิ่งที่กำลังจะมาถึง',
                            Icons.hourglass_bottom,
                            Colors.grey.shade600,
                            screenWidth,
                          ),
                          ...allUpcoming.map(
                            (item) => InkWell(
                              onTap: () => _showTaskDetailModal(
                                context,
                                item,
                              ), // Pass the whole item map
                              child:
                                  (item.containsKey('type') &&
                                      item['type'] == 'appointment')
                                  ? _buildAppointmentCardReadOnly(
                                      item['data'],
                                      screenWidth,
                                    ) // Appointment
                                  : _buildCountdownCard(
                                      item['data'],
                                      screenWidth,
                                    ), // Countdown
                            ),
                          ),
                        ],
                        const SizedBox(height: 10), // Padding at card bottom
                      ],
                    ),
                  );
                },
              );
              // --- End Grouped ListView ---
            },
          );
        },
      ),
    );
  }

  // --- WIDGETS FOR TASK CARDS ---
  Widget _buildAppointmentCard(
    Map<String, dynamic> task,
    String taskId,
    double screenWidth,
  ) {
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final groupId = task['groupId'] ?? '';
    final Timestamp? ts = task['taskDateTime'];
    String date = '-';
    String time = '-';
    // Check if overdue
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isOverdue = false;
    if (ts != null) {
      final dt = ts.toDate();
      date = DateFormat('d MMM y', 'th').format(dt);
      time = DateFormat('HH:mm').format(dt);
      final dtDayOnly = DateTime(dt.year, dt.month, dt.day);
      if (dt.isBefore(now) &&
          (dtDayOnly.isAtSameMomentAs(today) || dtDayOnly.isBefore(today))) {
        isOverdue = true;
      }
    }
    final cardColor = isOverdue ? _overdueColor : _appointmentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.radio_button_unchecked,
              color: cardColor,
              size: 28,
            ),
            onPressed: () {
              _showCompleteTaskDialog(context, taskId, groupId, taskTitle);
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              taskTitle,
              style: const TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 14,
                  color: cardColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCardReadOnly(
    Map<String, dynamic> task,
    double screenWidth,
  ) {
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final Timestamp? ts = task['taskDateTime'];
    String date = '-';
    String time = '-';
    if (ts != null) {
      final dt = ts.toDate();
      date = DateFormat('d MMM y', 'th').format(dt);
      time = DateFormat('HH:mm').format(dt);
    }
    final assignedToList = (task['assignedTo'] as List?)?.cast<String>() ?? [];
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appointmentColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.event_note, color: _appointmentColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: const TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (assignedToList.isNotEmpty)
                  FutureBuilder<Map<String, String>>(
                    future: _getUsernames(assignedToList),
                    builder: (context, snapshot) => Text(
                      'สำหรับ: ${snapshot.data?.values.join(', ') ?? '...'}',
                      style: const TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                date,
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 14,
                  color: _appointmentColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                time,
                style: const TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(Map<String, dynamic> task, double screenWidth) {
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final Timestamp? ts = task['taskDateTime'];
    if (ts == null) return ListTile(title: Text('$taskTitle (Missing Date)'));
    final dt = ts.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final days = target.difference(today).inDays;
    String dayStr = days < 0
        ? 'ผ่านไปแล้ว'
        : (days == 0 ? 'วันนี้!' : 'อีก $days วัน');
    final cardColor = days == 0 ? _todayEventColor : _countdownColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            days == 0 ? Icons.celebration : Icons.hourglass_bottom,
            color: cardColor,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              taskTitle,
              style: const TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            dayStr,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 20,
              color: cardColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitItemCard(
    Map<String, dynamic> itemData,
    double screenWidth,
  ) {
    final title = itemData['title'] ?? '-';
    final time = itemData['time'] ?? '-';
    final habitDocId = itemData['habitDocId'] ?? '';
    final groupId = itemData['groupId'] ?? '';
    final subTaskKey = itemData['subTaskKey'] ?? '';

    // Check if overdue
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isOverdue = false;
    final subTaskDateTime = _parseTimeString(time, today);
    if (subTaskDateTime != null && subTaskDateTime.isBefore(now)) {
      isOverdue = true;
    }
    final cardColor = isOverdue ? _overdueColor : _habitColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.radio_button_unchecked,
              color: cardColor,
              size: 28,
            ),
            onPressed: () {
              if (habitDocId.isNotEmpty &&
                  groupId.isNotEmpty &&
                  subTaskKey.isNotEmpty) {
                _showCompleteHabitItemDialog(
                  context,
                  habitDocId,
                  groupId,
                  subTaskKey,
                  title,
                  time,
                );
              }
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            time,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 16,
              color: cardColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHabitScheduleSummaryCard(
    Map<String, dynamic> task,
    double screenWidth,
  ) {
    final title = task['title'] ?? 'กิจวัตร';
    final schedule = (task['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final assigned = (task['assignedTo'] as List?)?.cast<String>() ?? [];
    List<String> days = [];
    for (int i = 1; i <= 7; i++) {
      if ((schedule[i.toString()] as List?)?.isNotEmpty ?? false) {
        days.add(_dayLabelsShort[i - 1]);
      }
    }
    final repeat = days.isNotEmpty ? 'ทำซ้ำ ${days.join(", ")}' : '-';
    return FutureBuilder<Map<String, String>>(
      future: _getUsernames(assigned),
      builder: (context, snapshot) {
        String assignSum = 'มอบหมายให้ ${assigned.length} คน';
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.values.isNotEmpty) {
          assignSum = 'มอบหมายให้: ${snapshot.data!.values.join(', ')}';
          if (assignSum.length > 40) {
            assignSum = 'มอบหมายให้ ${assigned.length} คน';
          }
        } else if (assigned.isEmpty) {
          assignSum = 'ไม่ได้มอบหมาย';
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _habitColor.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: _habitColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      repeat,
                      style: const TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      assignSum,
                      style: const TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    double screenWidth,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 10.0,
        bottom: 8.0,
        left: 16.0,
        right: 16.0,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color.withValues(alpha: 0.8),
            size: screenWidth * 0.05,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Divider(color: color.withValues(alpha: 0.3), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardItemCard(
    Map<String, dynamic> item,
    double screenWidth, {
    bool isCompleted = false,
  }) {
    final String type =
        item['type'] ?? 'unknown'; // 'habit_item', 'appointment', 'countdown'
    String title = 'ไม่มีชื่อ';
    String time = '--:--';
    List<String> assignedToIds = [];
    IconData itemIcon = Icons.task_alt; // Default icon
    Color itemColor = Colors.grey;
    String? completedByName; // Store completer name

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isOverdue = false;

    // Extract details based on item type
    if (type == 'habit_item') {
      title = item['title'] ?? 'กิจวัตร';
      time = item['time'] ?? '--:--'; // Today's habits just show time
      assignedToIds = (item['assignedTo'] as List?)?.cast<String>() ?? [];
      itemIcon = Icons.calendar_month_outlined; // <-- Habit icon
      // Check if overdue
      final subTaskDateTime = _parseTimeString(time, today);
      if (!isCompleted &&
          subTaskDateTime != null &&
          subTaskDateTime.isBefore(now)) {
        isOverdue = true;
      }
      itemColor = isCompleted
          ? _completedColor
          : (isOverdue ? _overdueColor : _habitColor);

      // Get completer ID if stored in history
      final String? completerId =
          item['data']?['completionHistory']?[item['subTaskKey'] + '_by'];
      if (completerId != null) {
        // Use cache directly, assumes _getUsernames was called
        completedByName = _userNameCache[completerId];
      }
    } else if (type == 'appointment') {
      final taskData = item['data'] as Map<String, dynamic>? ?? {};
      title = taskData['title'] ?? 'นัดหมาย';
      assignedToIds = (taskData['assignedTo'] as List?)?.cast<String>() ?? [];
      itemIcon = Icons.event_available_outlined; // <-- Appointment icon
      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        final dt = ts.toDate();
        if (!isCompleted && dt.isBefore(now)) {
          isOverdue = true;
        }

        // --- UPDATED DATE/TIME LOGIC ---
        final dtDayOnly = DateTime(dt.year, dt.month, dt.day);
        if (dtDayOnly.isBefore(today)) {
          // Overdue from a past day: Show Date + Time
          time = DateFormat('d MMM HH:mm', 'th').format(dt);
        } else {
          // Today's task: Show Time only
          time = DateFormat('HH:mm').format(dt);
        }
        // --- END UPDATE ---
      }
      itemColor = isCompleted
          ? _completedColor
          : (isOverdue ? _overdueColor : _appointmentColor);

      if (isCompleted) {
        final String? completerId = taskData['completedBy'];
        if (completerId != null) {
          completedByName = _userNameCache[completerId]; // Get from cache
        }
      }
    } else if (type == 'countdown') {
      final taskData = item['data'] as Map<String, dynamic>? ?? {};
      title = taskData['title'] ?? 'นับถอยหลัง';
      assignedToIds = []; // Countdowns aren't assigned
      itemIcon = Icons.hourglass_bottom; // <-- Countdown icon
      isOverdue = true; // It's in this list, so it's overdue
      itemColor = _overdueColor;

      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        final dt = ts.toDate();
        // Show the date it was for
        time = DateFormat('d MMM y', 'th').format(dt); // <-- Shows Date
      } else {
        time = 'ไม่มีวันที่';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withValues(alpha: 0.8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: itemColor.withValues(alpha: isCompleted ? 0.5 : 0.8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle
                : (isOverdue ? Icons.warning_amber_rounded : itemIcon),
            color: itemColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey[600] : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                FutureBuilder<Map<String, String>>(
                  future: _getUsernames(assignedToIds),
                  builder: (context, snapshot) {
                    String detailText;
                    if (isCompleted && completedByName != null) {
                      detailText = 'เสร็จสิ้นโดย: $completedByName';
                    } else if (isCompleted) {
                      detailText = 'เสร็จสิ้นแล้ว';
                    } else if (type == 'countdown') {
                      detailText = 'กิจกรรมผ่านไปแล้ว'; // <-- Countdown detail
                    } else if (snapshot.connectionState ==
                            ConnectionState.done &&
                        snapshot.hasData) {
                      detailText =
                          'สำหรับ: ${snapshot.data?.values.join(', ') ?? '?'}';
                    } else {
                      detailText = 'สำหรับ: ...';
                    }
                    return Text(
                      detailText,
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Display Time or Date
          Text(
            time,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              // --- UPDATED FONT SIZE ---
              // Make font smaller if it's a date (contains space)
              fontSize: (time.contains(' ') || type == 'countdown') ? 13 : 15,
              // --- END UPDATE ---
              color: itemColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- Sorting Helpers ---
  int _sortTaskItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    // Get timestamp if available (appt, countdown)
    Timestamp? tsA = a['data']?['taskDateTime'];
    Timestamp? tsB = b['data']?['taskDateTime'];

    // Get time string if available (habit)
    String timeA = (a['type'] == 'habit_item') ? a['time'] ?? '99:99' : "00:00";
    String timeB = (b['type'] == 'habit_item') ? b['time'] ?? '99:99' : "00:00";

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    DateTime? dateA = tsA?.toDate();
    DateTime? dateB = tsB?.toDate();

    // For habits, create a fake date for today
    if (a['type'] == 'habit_item') dateA = _parseTimeString(timeA, today);
    if (b['type'] == 'habit_item') dateB = _parseTimeString(timeB, today);

    // Handle null dates (e.g. habits with bad time)
    if (dateA == null && dateB == null) return 0;
    if (dateA == null) return 1;
    if (dateB == null) return -1;

    // Primary sort: Date (oldest first)
    return dateA.compareTo(dateB);
  }

  int _sortCompletedItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    // Try to get completion time first
    Timestamp? completedA = a['data']?['completedAt'];
    Timestamp? completedB = b['data']?['completedAt'];

    // For habits, completion is just a string, so we must sort by task time
    if (a['type'] == 'habit_item') completedA = null;
    if (b['type'] == 'habit_item') completedB = null;

    if (completedA != null && completedB != null) {
      return completedB.compareTo(completedA); // Newest completed first
    }
    if (completedA != null) return -1;
    if (completedB != null) return 1;

    // Fallback to sorting by task time if no completion timestamp
    return _sortTaskItems(a, b);
  }

  int _sortUpcomingItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    Timestamp? tsA = a['data']?['taskDateTime'];
    Timestamp? tsB = b['data']?['taskDateTime'];
    if (tsA == null && tsB == null) return 0;
    if (tsA == null) return 1;
    if (tsB == null) return -1;
    return tsA.compareTo(tsB); // Earliest upcoming first
  }

  // --- Functions for Completing Tasks ---
  Future<void> _completeHabitTask(
    String habitDocId,
    String groupId,
    String subTaskKey,
  ) async {
    if (groupId.isEmpty) {
      _showError("เกิดข้อผิดพลาด: ไม่พบรหัสกลุ่มสำหรับกิจวัตรนี้");
      return;
    }
    try {
      final taskRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(habitDocId);

      // Also store WHO completed it
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      await taskRef.update({
        'completionHistory.$subTaskKey': 'completed',
        'completionHistory.${subTaskKey}_by': userId, // Store completer
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ทำเครื่องหมายว่าเสร็จสิ้นแล้ว!',
            style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError("เกิดข้อผิดพลาดในการบันทึก: $e");
    }
  }

  void _showCompleteHabitItemDialog(
    BuildContext context,
    String habitDocId,
    String groupId,
    String subTaskKey,
    String taskTitle,
    String time,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ยืนยันการทำเสร็จสิ้น',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'คุณทำกิจวัตร "$taskTitle" ตอน $time เสร็จสิ้นแล้วใช่หรือไม่?',
            style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeHabitTask(habitDocId, groupId, subTaskKey);
              },
              child: const Text(
                'เสร็จสิ้น',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF2E88F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeTask(String taskId, String groupId) async {
    if (groupId.isEmpty) {
      _showError("เกิดข้อผิดพลาด: ไม่พบรหัสกลุ่ม");
      return;
    }
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('tasks')
          .doc(taskId)
          .update({
            'status': 'completed',
            'completedAt': FieldValue.serverTimestamp(),
            'completedBy': FirebaseAuth.instance.currentUser?.uid,
          });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ทำเครื่องหมายว่าเสร็จสิ้นแล้ว!',
            style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        _showError("เกิดข้อผิดพลาด: $e");
      }
    }
  }

  void _showCompleteTaskDialog(
    BuildContext context,
    String taskId,
    String groupId,
    String taskTitle,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'ยืนยันการทำเสร็จสิ้น',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'คุณทำงาน "$taskTitle" เสร็จสิ้นแล้วใช่หรือไม่?',
            style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
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
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _completeTask(taskId, groupId);
              },
              child: const Text(
                'เสร็จสิ้น',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Color(0xFF2E88F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Empty State Widget ---
  Widget _buildEmptyTaskList(double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: const Color(0xFF7ED6A8)),
          const SizedBox(height: 20),
          Text(
            'ยอดเยี่ยม!',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.06,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF374151),
            ),
          ),
          Text(
            _userRole == 'carereceiver'
                ? 'คุณไม่มีงานค้างในวันนี้'
                : 'ไม่มีงานที่รอดำเนินการในกลุ่มของคุณ',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.04,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Clears all old notifications and schedules new ones for the Care Receiver.
  Future<void> _scheduleReceiverNotifications(
    List<DocumentSnapshot> taskDocs,
    String currentUserId,
  ) async {
    // 1. Clear all previously scheduled notifications to prevent duplicates
    await _notificationService.cancelAllNotifications();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayWeekday = today.weekday;
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    int notificationId = 0; // Unique ID for each notification

    for (var doc in taskDocs) {
      final task = doc.data() as Map<String, dynamic>?;
      if (task == null) continue;

      final groupId = task['groupId'] ?? '';
      final assignedTo = (task['assignedTo'] as List?)?.cast<String>() ?? [];
      final type = task['taskType'] ?? '';

      // Only schedule for tasks assigned to this user
      if (!assignedTo.contains(currentUserId)) continue;

      if (type == 'appointment') {
        final Timestamp? ts = task['taskDateTime'];
        if (ts == null) continue;

        final DateTime taskDate = ts.toDate();
        final String title = task['title'] ?? 'นัดหมาย';
        final String groupName = _groupNameCache[groupId] ?? '...';
        final String payload = "appointment/$groupId/${doc.id}";

        // Schedule "At-Due-Time" notification
        if (taskDate.isAfter(now)) {
          notificationId++;
          _notificationService.scheduleTaskNotification(
            id: notificationId,
            title: 'ถึงเวลา: $title',
            body: 'จากกลุ่ม: $groupName',
            scheduledTime: taskDate,
            payload: payload,
            withActions: true, // <-- Adds "Completed" button
          );
        }

        // Schedule "1-Hour-Before" notification
        final DateTime oneHourBefore = taskDate.subtract(
          const Duration(hours: 1),
        );
        if (oneHourBefore.isAfter(now)) {
          notificationId++;
          _notificationService.scheduleTaskNotification(
            id: notificationId,
            title: 'อีก 1 ชั่วโมง: $title',
            body: 'จากกลุ่ม: $groupName',
            scheduledTime: oneHourBefore,
            payload: payload,
            withActions: false,
          );
        }
      } else if (type == 'habit_schedule') {
        final schedule =
            (task['schedule'] as Map?)?.cast<String, List<dynamic>>() ?? {};
        final tasksForTodayDynamic = schedule[todayWeekday.toString()];

        if (tasksForTodayDynamic != null && tasksForTodayDynamic.isNotEmpty) {
          final completionHistory =
              (task['completionHistory'] as Map?)?.cast<String, String>() ?? {};

          for (var subTask in tasksForTodayDynamic) {
            final subTaskTimeStr = subTask['time'] ?? '';
            final subTaskTitle = subTask['title'] ?? '';
            final subTaskKey = '${todayKey}_${subTaskTimeStr}_$subTaskTitle';
            final isCompleted = completionHistory[subTaskKey] == 'completed';

            // Don't schedule if already completed
            if (isCompleted) continue;

            final DateTime? taskDate = _parseTimeString(subTaskTimeStr, today);
            if (taskDate == null) continue;

            final String groupName = _groupNameCache[groupId] ?? '...';
            // Payload needs subTaskKey to complete the right habit item
            final String payload = "habit/$groupId/${doc.id}/$subTaskKey";

            // Schedule "At-Due-Time" notification
            if (taskDate.isAfter(now)) {
              notificationId++;
              _notificationService.scheduleTaskNotification(
                id: notificationId,
                title: 'ถึงเวลา: $subTaskTitle',
                body: 'จากกลุ่ม: $groupName',
                scheduledTime: taskDate,
                payload: payload,
                withActions: true, // <-- Adds "Completed" button
              );
            }

            // Schedule "1-Hour-Before" notification
            final DateTime oneHourBefore = taskDate.subtract(
              const Duration(hours: 1),
            );
            if (oneHourBefore.isAfter(now)) {
              notificationId++;
              _notificationService.scheduleTaskNotification(
                id: notificationId,
                title: 'อีก 1 ชั่วโมง: $subTaskTitle',
                body: 'จากกลุ่ม: $groupName',
                scheduledTime: oneHourBefore,
                payload: payload,
                withActions: false,
              );
            }
          }
        }
      }
    }
    // print("Scheduled $notificationId local notifications.");
  }

  /// Shows a modal dialog with task details.
  void _showTaskDetailModal(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) {
    // --- Define Thai names for tags ---
    final Map<String, String> _taskTypeNames = {
      'appointment': "นัดหมาย",
      'countdown': "นับถอยหลัง",
      'habit_item': "กิจวัตร",
      'habit_schedule': "ตารางกิจวัตร",
      'unknown': 'งาน',
    };

    // Extract common data
    final String type = itemData['type'] ?? 'unknown';
    final Map<String, dynamic> taskData = itemData['data'] ?? {};
    final String taskId =
        itemData['id'] ?? itemData['habitDocId'] ?? 'unknown_id';

    // --- FIX 1: Use _groupDataCache ---
    final String groupId =
        itemData['groupId'] ?? taskData['groupId'] ?? 'unknown_group';
    // Get the data map from the new cache
    final Map<String, String?>? groupData = _groupDataCache[groupId];
    // Get the name from the map, providing a fallback
    final String groupName = groupData?['name'] ?? 'Loading...';
    // --- END FIX 1 ---

    String title = taskData['title'] ?? itemData['title'] ?? 'No Title';
    final String description = taskData['description'] ?? '';
    final List<String> assignedToIds =
        (taskData['assignedTo'] as List?)?.cast<String>() ??
        (itemData['assignedTo'] as List?)?.cast<String>() ??
        [];
    final bool isCompleted =
        itemData['isCompleted'] ?? (taskData['status'] == 'completed');
    final Timestamp? completedAt = taskData['completedAt'];

    // --- (Includes previous fix for subTaskKey): Safe subTaskKey access ---
    final String? subTaskKey = itemData['subTaskKey'];
    final Map<String, dynamic>? completionHistory =
        taskData['completionHistory'] as Map<String, dynamic>?;
    String? completedByUid = taskData['completedBy']; // Check appointment first
    if (completedByUid == null &&
        subTaskKey != null &&
        completionHistory != null) {
      // If not from appointment, and we have a subTaskKey and history, look it up
      completedByUid =
          completionHistory['${subTaskKey}_by']; // Use interpolation
    }
    // --- END FIX ---

    IconData typeIcon = Icons.task;
    Color typeColor = Colors.grey;
    String typeText = _taskTypeNames[type] ?? "Task"; // Use Thai name
    String dateTimeText = "";

    // Type-specific details
    if (type == 'appointment') {
      typeIcon = Icons.event_available_outlined;
      typeColor = _appointmentColor;
      title = taskData['title'] ?? 'Appointment';
      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        dateTimeText =
            "ถึงกำหนด: ${DateFormat('d MMM y HH:mm', 'th').format(ts.toDate())}";
      }
    } else if (type == 'habit_item') {
      typeIcon = Icons.calendar_month_outlined;
      typeColor = _habitColor;
      title = itemData['title'] ?? 'Habit Task';
      dateTimeText = "เวลา: ${itemData['time'] ?? '--:--'} (วันนี้)";
    } else if (type == 'countdown') {
      typeIcon = Icons.hourglass_bottom;
      typeColor = _countdownColor;
      title = taskData['title'] ?? 'Countdown';
      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        dateTimeText =
            "วันเป้าหมาย: ${DateFormat('d MMM y', 'th').format(ts.toDate())}";
      }
    } else if (type == 'habit_schedule') {
      // For the summary card
      typeIcon = Icons.calendar_month;
      typeColor = _habitColor;
      title = taskData['title'] ?? 'Habit Schedule';
      final schedule =
          (taskData['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
      List<String> days = [];
      int totalItems = 0;
      for (int i = 1; i <= 7; i++) {
        final dayTasks = (schedule[i.toString()] as List?);
        if (dayTasks?.isNotEmpty ?? false) {
          days.add(_dayLabelsShort[i - 1]);
          totalItems += dayTasks!.length;
        }
      }
      dateTimeText = days.isNotEmpty
          ? 'ทำซ้ำ: ${days.join(", ")} (รวม $totalItems รายการ)'
          : 'ไม่มีตารางเวลา';
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          titlePadding: const EdgeInsets.all(20).copyWith(bottom: 0),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          title: Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: typeColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Divider(color: typeColor.withOpacity(0.3)),

                // --- ENHANCEMENT 2: Add Task Type Tag ---
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      typeText, // The Thai name
                      style: TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        color: typeColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // --- END ENHANCEMENT ---
                if (description.isNotEmpty) ...[
                  const Text(
                    'รายละเอียด:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(description),
                  const SizedBox(height: 10),
                ],
                if (dateTimeText.isNotEmpty) ...[
                  Text(
                    dateTimeText,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                ],
                // This now uses the fixed groupName
                Text(
                  'กลุ่ม: $groupName',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 10),

                // Assigned To / Completed By section
                if (assignedToIds.isNotEmpty || completedByUid != null)
                  FutureBuilder<Map<String, String>>(
                    future: _getUsernames([
                      ...assignedToIds,
                      if (completedByUid != null) completedByUid,
                    ]),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Text('กำลังโหลด...');
                      }

                      final names = snapshot.data ?? {};
                      final assignedNames = assignedToIds
                          .map((id) => names[id] ?? 'ไม่พบชื่อ')
                          .join(', ');
                      final completerName = names[completedByUid];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (assignedToIds.isNotEmpty &&
                              type != 'habit_schedule')
                            Text('มอบหมายให้: $assignedNames'),
                          if (isCompleted && completerName != null) ...[
                            const SizedBox(height: 5),
                            Text(
                              'เสร็จสิ้นโดย: $completerName' +
                                  (completedAt != null
                                      ? ' เมื่อ ${DateFormat('d MMM, HH:mm', 'th').format(completedAt.toDate())}'
                                      : ''),
                              style: TextStyle(
                                color: _completedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ] else if (isCompleted) ...[
                            const SizedBox(height: 5),
                            Text(
                              'เสร็จสิ้นแล้ว' +
                                  (completedAt != null
                                      ? ' เมื่อ ${DateFormat('d MMM, HH:mm', 'th').format(completedAt.toDate())}'
                                      : ''),
                              style: TextStyle(
                                color: _completedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'ปิด',
                style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }
} // End of _HomeScreenState
