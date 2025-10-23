// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import '../widgets/custom_button.dart';
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

  final Map<String, Color> dayColors = {
    'Monday': Colors.yellow.shade700,
    'Tuesday': Colors.pink.shade400,
    'Wednesday': Colors.green.shade500,
    'Thursday': Colors.orange.shade600,
    'Friday': Colors.blue.shade500,
    'Saturday': Colors.purple.shade400,
    'Sunday': Colors.red.shade500,
  };
  final List<String> _dayLabelsShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];

  // Consistent Task Type Colors
  final Color _appointmentColor = const Color(0xFF2E88F3); // Blue
  final Color _countdownColor = const Color(0xFF7ED6A8); // Green
  final Color _habitColor = Colors.purple.shade300; // Purple
  final Color _completedColor = Colors.green.shade600; // Completed Green

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
      print('Error fetching user data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _getUsername(String userId) async {
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final name = userDoc.data()?['username'] ?? 'ไม่ทราบชื่อ';
        _userNameCache[userId] = name;
        return name;
      }
    } catch (e) {
      print("Error getting username for $userId: $e");
    }
    return 'ไม่ทราบชื่อ';
  }

  Future<Map<String, String>> _getUsernames(List<String> userIds) async {
    Map<String, String> names = {};
    List<String> idsToFetch = [];
    for (String id in userIds.toSet()) {
      if (!_userNameCache.containsKey(id) && id.isNotEmpty)
        idsToFetch.add(id);
      else if (_userNameCache.containsKey(id))
        names[id] = _userNameCache[id]!;
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
          for (var doc in querySnapshot.docs) {
            final name = doc.data()['username'] ?? 'ไม่ทราบชื่อ';
            _userNameCache[doc.id] = name;
            names[doc.id] = name;
          }
        }
      } catch (e) {
        print("Error getting usernames: $e");
      }
    }
    for (String id in userIds) {
      names.putIfAbsent(id, () => _userNameCache[id] ?? 'ไม่ทราบชื่อ');
    }
    return names;
  }

  Future<String> _getGroupName(String groupId) async {
    if (_groupNameCache.containsKey(groupId)) return _groupNameCache[groupId]!;
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      if (groupDoc.exists) {
        final name = groupDoc.data()?['groupName'] ?? 'กลุ่มไม่มีชื่อ';
        _groupNameCache[groupId] = name;
        return name;
      }
    } catch (e) {
      print("Error getting group name for $groupId: $e");
    }
    _groupNameCache[groupId] = 'กลุ่มไม่มีชื่อ';
    return 'กลุ่มไม่มีชื่อ';
  }

  Future<void> _getGroupNames(List<String> groupIds) async {
    List<String> idsToFetch = [];
    for (String id in groupIds.toSet()) {
      if (!_groupNameCache.containsKey(id) && id.isNotEmpty) {
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
            final name = doc.data()['groupName'] ?? 'กลุ่มไม่มีชื่อ';
            _groupNameCache[doc.id] = name;
          }
        }
      } catch (e) {
        print("Error getting group names: $e");
      }
    }
    for (String id in groupIds) {
      _groupNameCache.putIfAbsent(id, () => 'กลุ่มไม่มีชื่อ');
    }
    if (idsToFetch.isNotEmpty && mounted) {
      setState(() {});
    } // Trigger rebuild after fetching
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
        MaterialPageRoute(builder: (context) => const GroupsScreen()),
      );
    } else if (index == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SettingsScreen()),
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
    final weekdayName = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][today.weekday - 1];
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
                    SizedBox(height: screenHeight * 0.02),
                    _buildTodayLabel(weekdayName, screenWidth),
                    SizedBox(height: screenHeight * 0.03),
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
              'สวัสดี',
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

  Widget _buildTodayLabel(String weekdayName, double screenWidth) {
    return Text(
      weekdayName,
      style: TextStyle(
        fontFamily: 'NotoLoopedThaiUI',
        fontSize: screenWidth * 0.06,
        fontWeight: FontWeight.bold,
        color: dayColors[weekdayName] ?? Colors.black,
      ),
    );
  }

  // --- REFINED: Content for Caretakers (Grouped Dashboard) ---
  Widget _buildCaretakerContent(double screenWidth) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Expanded(child: Center(child: Text('ไม่พบผู้ใช้งาน')));

    return Expanded(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!userSnapshot.hasData || !userSnapshot.data!.exists)
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));

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
              if (taskSnapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (taskSnapshot.hasError)
                return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดงาน'));
              if (!taskSnapshot.hasData || taskSnapshot.data!.docs.isEmpty)
                return _buildEmptyTaskList(screenWidth);

              final allTasks = taskSnapshot.data!.docs;
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
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
                    'completed_today': [],
                    'habits': [],
                    'upcoming': [],
                  },
                );
                final Timestamp? ts = task['taskDateTime'];
                DateTime? taskDate;
                DateTime? taskDayOnly;
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
                      final subTaskTime = subTask['time'] ?? '';
                      final subTaskTitle = subTask['title'] ?? '';
                      final subTaskKey =
                          '${todayKey}_${subTaskTime}_$subTaskTitle';
                      final isCompleted =
                          completionHistory[subTaskKey] == 'completed';
                      final itemData = {
                        'type': 'habit_item',
                        'id': doc.id,
                        'groupId': groupId,
                        'subTaskKey': subTaskKey,
                        'time': subTaskTime,
                        'title': subTaskTitle,
                        'assignedTo': assignedTo,
                        'isCompleted': isCompleted,
                        'data': task,
                      }; // Pass main task data for context
                      if (isCompleted) {
                        groupedCategorizedTasks[groupId]!['completed_today']!
                            .add(itemData);
                      } else {
                        groupedCategorizedTasks[groupId]!['pending_today']!.add(
                          itemData,
                        );
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
                    } else {
                      groupedCategorizedTasks[groupId]!['pending_today']!.add({
                        'type': 'appointment',
                        'id': doc.id,
                        'groupId': groupId,
                        'data': task,
                        'isCompleted': false,
                      });
                    }
                  } else if (taskDate != null && taskDate.isAfter(today)) {
                    groupedCategorizedTasks[groupId]!['upcoming']!.add({
                      'type': 'appointment',
                      'id': doc.id,
                      'groupId': groupId,
                      'data': task,
                    });
                  } else if (taskDate != null &&
                      taskDate.isBefore(today) &&
                      status == 'pending') {
                    // Overdue appointments - add to pending
                    groupedCategorizedTasks[groupId]!['pending_today']!.add({
                      'type': 'appointment',
                      'id': doc.id,
                      'groupId': groupId,
                      'data': task,
                      'isCompleted': false,
                    });
                  }
                } else if (type == 'countdown') {
                  if (taskDate != null &&
                      (taskDate.isAtSameMomentAs(today) ||
                          taskDate.isAfter(today))) {
                    groupedCategorizedTasks[groupId]!['upcoming']!.add({
                      'type': 'countdown',
                      'id': doc.id,
                      'groupId': groupId,
                      'data': task,
                    });
                  }
                }
              }

              _getUsernames(usersToFetch.toList()); // Fetch names

              // Sort items within categories for each group
              groupedCategorizedTasks.forEach((groupId, categories) {
                categories['pending_today']?.sort(_sortTaskItems);
                categories['completed_today']?.sort(_sortCompletedItems);
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
                    categories['completed_today']!.isNotEmpty ||
                    categories['habits']!.isNotEmpty ||
                    categories['upcoming']!.isNotEmpty;
              }).toList();

              if (relevantGroupIds.isEmpty)
                return _buildEmptyTaskList(screenWidth);

              // --- Build Grouped ListView ---
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: relevantGroupIds.length,
                itemBuilder: (context, index) {
                  final groupId = relevantGroupIds[index];
                  final groupName = _groupNameCache[groupId] ?? 'Loading...';
                  final categories = groupedCategorizedTasks[groupId]!;
                  final pendingToday = categories['pending_today']!;
                  final completedToday = categories['completed_today']!;
                  final habits = categories['habits']!;
                  final upcoming = categories['upcoming']!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Group Header
                      Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : 24.0,
                          bottom: 10.0,
                        ),
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.055,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      // Sections for this group
                      if (pendingToday.isNotEmpty) ...[
                        _buildSectionHeader(
                          'วันนี้ (รอดำเนินการ)',
                          Icons.radio_button_unchecked,
                          Colors.orange,
                          screenWidth,
                        ),
                        ...pendingToday
                            .map(
                              (item) =>
                                  _buildDashboardItemCard(item, screenWidth),
                            )
                            .toList(),
                      ],
                      if (completedToday.isNotEmpty) ...[
                        _buildSectionHeader(
                          'วันนี้ (เสร็จสิ้น)',
                          Icons.check_circle,
                          _completedColor,
                          screenWidth,
                        ),
                        ...completedToday
                            .map(
                              (item) => _buildDashboardItemCard(
                                item,
                                screenWidth,
                                isCompleted: true,
                              ),
                            )
                            .toList(),
                      ],
                      if (habits.isNotEmpty) ...[
                        _buildSectionHeader(
                          'กิจวัตรที่ใช้งานอยู่',
                          Icons.calendar_month,
                          _habitColor,
                          screenWidth,
                        ),
                        ...habits
                            .map(
                              (item) => _buildHabitScheduleSummaryCard(
                                item['data'],
                                screenWidth,
                              ),
                            )
                            .toList(),
                      ],
                      if (upcoming.isNotEmpty) ...[
                        _buildSectionHeader(
                          'งานที่กำลังจะมาถึง',
                          Icons.hourglass_bottom,
                          Colors.grey,
                          screenWidth,
                        ),
                        ...upcoming
                            .map(
                              (item) => item['type'] == 'countdown'
                                  ? _buildCountdownCard(
                                      item['data'],
                                      screenWidth,
                                    )
                                  : _buildAppointmentCardReadOnly(
                                      item['data'],
                                      screenWidth,
                                    ),
                            )
                            .toList(),
                      ],

                      // Add a small divider between groups if desired
                      if (index < relevantGroupIds.length - 1)
                        const Divider(height: 30, thickness: 0.5),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- UPDATED: Content for Care Receivers (Grouped & Categorized) ---
  Widget _buildCareReceiverContent(double screenWidth) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null)
      return const Expanded(child: Center(child: Text('ไม่พบผู้ใช้งาน')));
    final todayWeekday = DateTime.now().weekday;
    final todayDateKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Expanded(
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!userSnapshot.hasData || !userSnapshot.data!.exists)
            return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));

          final userData = userSnapshot.data!.data() as Map<String, dynamic>;
          final List<String> joinedGroups =
              (userData['joinedGroups'] as List?)?.cast<String>() ?? [];
          if (joinedGroups.isEmpty) return _buildEmptyTaskList(screenWidth);

          _getGroupNames(joinedGroups); // Pre-fetch names

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collectionGroup('tasks')
                .where('groupId', whereIn: joinedGroups)
                .snapshots(),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              if (taskSnapshot.hasError)
                return const Center(child: Text('เกิดข้อผิดพลาดในการโหลดงาน'));
              if (!taskSnapshot.hasData ||
                  taskSnapshot.data == null ||
                  taskSnapshot.data!.docs.isEmpty)
                return _buildEmptyTaskList(screenWidth);

              final allTasks = taskSnapshot.data!.docs;
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

                // Initialize group map
                groupedCategorizedTasks.putIfAbsent(
                  groupId,
                  () => {
                    'pending_habits': [],
                    'pending_appointments': [],
                    'upcoming_countdowns': [],
                  },
                );

                // Categorize and Filter
                if (type == 'habit_schedule' && assignedTo.contains(user.uid)) {
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
                      final subTaskTime = subTask['time'] ?? 'no_time_$i';
                      final subTaskTitle = subTask['title'] ?? 'no_title_$i';
                      final subTaskKey =
                          '${todayDateKey}_${subTaskTime}_$subTaskTitle';
                      final isCompleted =
                          completionHistory[subTaskKey] == 'completed';
                      if (!isCompleted) {
                        groupedCategorizedTasks[groupId]!['pending_habits']!
                            .add({
                              'habitDocId': doc.id,
                              'groupId': groupId,
                              'subTaskKey': subTaskKey,
                              'time': subTaskTime.startsWith('no_time')
                                  ? '--:--'
                                  : subTaskTime,
                              'title': subTaskTitle.startsWith('no_title')
                                  ? 'ไม่มีชื่อ'
                                  : subTaskTitle,
                            });
                      }
                    }
                  }
                } else if (type == 'appointment' &&
                    status == 'pending' &&
                    assignedTo.contains(user.uid)) {
                  groupedCategorizedTasks[groupId]!['pending_appointments']!
                      .add({'id': doc.id, 'data': task});
                } else if (type == 'countdown') {
                  final Timestamp? ts = task['taskDateTime'];
                  if (ts == null) continue;
                  final taskDate = ts.toDate();
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  if (taskDate.isAtSameMomentAs(today) ||
                      taskDate.isAfter(today)) {
                    groupedCategorizedTasks[groupId]!['upcoming_countdowns']!
                        .add({'id': doc.id, 'data': task});
                  }
                }
              }
              // --- End Grouping ---

              // Sort items within each group's categories
              groupedCategorizedTasks.forEach((key, categories) {
                categories['pending_habits']?.sort(
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
                categories['upcoming_countdowns']?.sort(
                  (a, b) =>
                      (a['data']['taskDateTime'] as Timestamp?)?.compareTo(
                        b['data']['taskDateTime'] as Timestamp? ??
                            Timestamp.now(),
                      ) ??
                      0,
                );
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
                    categories['upcoming_countdowns']!.isNotEmpty;
              }).toList();

              if (relevantGroupIds.isEmpty)
                return _buildEmptyTaskList(screenWidth);

              // --- Build Grouped ListView for CareReceiver ---
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: relevantGroupIds.length,
                itemBuilder: (context, index) {
                  final groupId = relevantGroupIds[index];
                  final groupName = _groupNameCache[groupId] ?? 'Loading...';
                  final categories = groupedCategorizedTasks[groupId]!;
                  final pendingHabits = categories['pending_habits']!;
                  final pendingAppointments =
                      categories['pending_appointments']!;
                  final upcomingCountdowns = categories['upcoming_countdowns']!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: index == 0 ? 0 : 24.0,
                          bottom: 10.0,
                        ),
                        child: Text(
                          groupName,
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ),

                      // Display pending items combined or sectioned? Let's section.
                      if (pendingHabits.isNotEmpty) ...[
                        _buildSectionHeader(
                          'กิจวัตรวันนี้',
                          Icons.calendar_month_outlined,
                          _habitColor,
                          screenWidth,
                        ),
                        ...pendingHabits
                            .map(
                              (item) => _buildHabitItemCard(item, screenWidth),
                            )
                            .toList(),
                      ],
                      if (pendingAppointments.isNotEmpty) ...[
                        _buildSectionHeader(
                          'นัดหมายวันนี้/ค้าง',
                          Icons.event_available_outlined,
                          _appointmentColor,
                          screenWidth,
                        ),
                        ...pendingAppointments
                            .map(
                              (item) => _buildAppointmentCard(
                                item['data'],
                                item['id'],
                                screenWidth,
                              ),
                            )
                            .toList(),
                      ],
                      if (upcomingCountdowns.isNotEmpty) ...[
                        _buildSectionHeader(
                          'การนับถอยหลัง',
                          Icons.hourglass_bottom_outlined,
                          _countdownColor,
                          screenWidth,
                        ),
                        ...upcomingCountdowns
                            .map(
                              (item) => _buildCountdownCard(
                                item['data'],
                                screenWidth,
                              ),
                            )
                            .toList(),
                      ],
                      // Add a small divider between groups if desired
                      if (index < relevantGroupIds.length - 1)
                        const Divider(height: 30, thickness: 0.5),
                    ],
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
    /* ... unchanged ... */
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final groupId = task['groupId'] ?? '';
    final Timestamp? ts = task['taskDateTime'];
    String date = '-';
    String time = '-';
    if (ts != null) {
      final dt = ts.toDate();
      date = DateFormat('d MMM y', 'th').format(dt);
      time = DateFormat('HH:mm').format(dt);
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appointmentColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: _appointmentColor,
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

  Widget _buildAppointmentCardReadOnly(
    Map<String, dynamic> task,
    double screenWidth,
  ) {
    /* ... unchanged ... */
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _appointmentColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
    /* ... unchanged ... */
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
        : (days == 0 ? 'วันนี้!' : '$days วัน');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _countdownColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_bottom, color: _countdownColor),
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
              color: _countdownColor,
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
    /* ... unchanged ... */
    final title = itemData['title'] ?? '-';
    final time = itemData['time'] ?? '-';
    final habitDocId = itemData['habitDocId'] ?? '';
    final groupId = itemData['groupId'] ?? '';
    final subTaskKey = itemData['subTaskKey'] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _habitColor.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              color: _habitColor,
              size: 28,
            ),
            onPressed: () {
              if (habitDocId.isNotEmpty &&
                  groupId.isNotEmpty &&
                  subTaskKey.isNotEmpty)
                _showCompleteHabitItemDialog(
                  context,
                  habitDocId,
                  groupId,
                  subTaskKey,
                  title,
                  time,
                );
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
              color: _habitColor,
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
    /* ... unchanged ... */
    final title = task['title'] ?? 'กิจวัตร';
    final schedule = (task['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final assigned = (task['assignedTo'] as List?)?.cast<String>() ?? [];
    List<String> days = [];
    for (int i = 1; i <= 7; i++) {
      if ((schedule[i.toString()] as List?)?.isNotEmpty ?? false)
        days.add(_dayLabelsShort[i - 1]);
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
          if (assignSum.length > 40)
            assignSum = 'มอบหมายให้ ${assigned.length} คน';
        } else if (assigned.isEmpty)
          assignSum = 'ไม่ได้มอบหมาย';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _habitColor.withOpacity(0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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
    /* ... unchanged ... */
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: screenWidth * 0.05),
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
          Expanded(child: Divider(color: color.withOpacity(0.3), thickness: 1)),
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
        item['type'] ?? 'unknown'; // 'habit_item' or 'appointment'
    String title = 'ไม่มีชื่อ';
    String time = '--:--';
    List<String> assignedToIds = [];
    IconData itemIcon = Icons.task_alt; // Default icon
    Color itemColor = Colors.grey;
    String? completedByName; // Store completer name

    // Extract details based on item type
    if (type == 'habit_item') {
      title = item['title'] ?? 'กิจวัตร';
      time = item['time'] ?? '--:--';
      // 'assignedTo' should be in the item map if extracted correctly
      assignedToIds = (item['assignedTo'] as List?)?.cast<String>() ?? [];
      itemIcon = Icons.calendar_month_outlined; // Use outlined version
      itemColor = isCompleted
          ? _completedColor
          : _habitColor; // Use state colors
      // Get completer ID if stored in history (e.g., '2023-10-27_08:00_Meds_by') - Requires modification
      // final String? completerId = item['data']?['completionHistory']?[item['subTaskKey']+'_by'];
      // if (completerId != null) completedByName = _userNameCache[completerId];
    } else if (type == 'appointment') {
      final taskData = item['data'] as Map<String, dynamic>? ?? {};
      title = taskData['title'] ?? 'นัดหมาย';
      assignedToIds = (taskData['assignedTo'] as List?)?.cast<String>() ?? [];
      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        time = DateFormat('HH:mm').format(ts.toDate()); // Format time
      }
      itemIcon = Icons.event_available_outlined; // Use outlined version
      itemColor = isCompleted
          ? _completedColor
          : _appointmentColor; // Use state colors
      // Get completer name if the appointment is completed
      if (isCompleted) {
        final String? completerId = taskData['completedBy'];
        if (completerId != null) {
          completedByName = _userNameCache[completerId]; // Get from cache
        }
      }
    }
    // Add cases for other types if needed (e.g., if you show countdowns here)

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Smaller margin
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ), // Adjust padding
      decoration: BoxDecoration(
        color: isCompleted
            ? Colors.white.withOpacity(0.8)
            : Colors.white, // Slightly faded if completed
        borderRadius: BorderRadius.circular(8), // Smaller radius
        border: Border.all(
          color: itemColor.withOpacity(isCompleted ? 0.5 : 0.8),
        ), // Border matching color
        boxShadow: [
          BoxShadow(
            // Subtle shadow
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : itemIcon,
            color: itemColor,
            size: 20,
          ), // Show check if completed
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    fontSize: 15, // Slightly smaller font
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted
                        ? TextDecoration.lineThrough
                        : null, // Strikethrough if completed
                    color: isCompleted ? Colors.grey[600] : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Show assigned user(s) or completed by user
                FutureBuilder<Map<String, String>>(
                  future: _getUsernames(assignedToIds), // Fetch assignee names
                  builder: (context, snapshot) {
                    String detailText;
                    if (isCompleted && completedByName != null) {
                      detailText = 'เสร็จสิ้นโดย: $completedByName';
                    } else if (!isCompleted &&
                        snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      // Show assignees if not completed
                      detailText =
                          'สำหรับ: ${snapshot.data?.values.join(', ') ?? '?'}';
                    } else if (!isCompleted) {
                      detailText = 'สำหรับ: ...'; // Loading assignees
                    } else {
                      detailText =
                          'เสร็จสิ้นแล้ว'; // Fallback if completer name missing
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
          // Display Time
          Text(
            time,
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 15,
              color: itemColor, // Use item color
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- Sorting Helpers ---
  int _sortTaskItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    /* ... unchanged ... */
    String tA = "99:99";
    Timestamp? tsA;
    String tB = "99:99";
    Timestamp? tsB;
    if (a['type'] == 'habit_item') tA = a['time'] ?? '99:99';
    if (a['type'] == 'appointment') tsA = a['data']?['taskDateTime'];
    if (b['type'] == 'habit_item') tB = b['time'] ?? '99:99';
    if (b['type'] == 'appointment') tsB = b['data']?['taskDateTime'];
    if (tsA != null && tsB != null) {
      final dtA = tsA.toDate();
      final dtB = tsB.toDate();
      if (dtA.year != dtB.year) return dtA.year.compareTo(dtB.year);
      if (dtA.month != dtB.month) return dtA.month.compareTo(dtB.month);
      if (dtA.day != dtB.day) return dtA.day.compareTo(dtB.day);
      return dtA.hour * 60 + dtA.minute.compareTo(dtB.hour * 60 + dtB.minute);
    }
    if (tsA != null) return -1;
    if (tsB != null) return 1;
    return tA.compareTo(tB);
  }

  int _sortCompletedItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    /* ... unchanged ... */
    Timestamp? completedA = a['data']?['completedAt'];
    Timestamp? completedB = b['data']?['completedAt'];
    if (completedA != null && completedB != null)
      return completedB.compareTo(completedA);
    if (completedA != null) return -1;
    if (completedB != null) return 1;
    return _sortPendingItems(a, b);
  }

  int _sortUpcomingItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    /* ... unchanged ... */
    Timestamp? tsA = a['data']?['taskDateTime'];
    Timestamp? tsB = b['data']?['taskDateTime'];
    if (tsA == null && tsB == null) return 0;
    if (tsA == null) return 1;
    if (tsB == null) return -1;
    return tsA.compareTo(tsB);
  }

  int _sortPendingItems(Map<String, dynamic> a, Map<String, dynamic> b) {
    String timeA = "99:99";
    Timestamp? tsA;
    String timeB = "99:99";
    Timestamp? tsB;

    // Extract time string for habits, timestamp for appointments
    if (a['type'] == 'habit_item') timeA = a['time'] ?? '99:99';
    if (a['type'] == 'appointment') tsA = a['data']?['taskDateTime'];
    if (b['type'] == 'habit_item') timeB = b['time'] ?? '99:99';
    if (b['type'] == 'appointment') tsB = b['data']?['taskDateTime'];

    // Prioritize overdue appointments first
    DateTime? dateA = tsA?.toDate();
    DateTime? dateB = tsB?.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool aIsPast = dateA != null && dateA.isBefore(today);
    bool bIsPast = dateB != null && dateB.isBefore(today);
    if (aIsPast != bIsPast) return aIsPast ? -1 : 1; // Overdue items come first

    // Sort appointments primarily by timestamp (date then time)
    if (tsA != null && tsB != null) {
      int dateComparison = tsA.compareTo(tsB);
      if (dateComparison != 0) return dateComparison;
      // If same date, sort by time part (though timestamp comparison already does this)
    }
    // If comparing appointment and habit, appointment generally comes first unless habit time is earlier on the same day
    if (tsA != null && dateA != null) {
      // a is appointment
      final dtA = dateA;
      if (b['type'] == 'habit_item' && dtA.isAtSameMomentAs(today)) {
        // Compare appointment time with habit time string for today
        final timeStrA = DateFormat('HH:mm').format(dtA);
        return timeStrA.compareTo(timeB);
      }
      return -1; // Appointment comes before habit on different days or future
    }
    if (tsB != null && dateB != null) {
      // b is appointment
      final dtB = dateB;
      if (a['type'] == 'habit_item' && dtB.isAtSameMomentAs(today)) {
        final timeStrB = DateFormat('HH:mm').format(dtB);
        return timeA.compareTo(timeStrB);
      }
      return 1; // Appointment comes before habit
    }

    // If both are habits or timestamps are null, sort by time string
    return timeA.compareTo(timeB);
  }

  // --- Functions for Completing Tasks ---
  Future<void> _completeHabitTask(
    String habitDocId,
    String groupId,
    String subTaskKey,
  ) async {
    /* ... unchanged ... */
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
      await taskRef.update({'completionHistory.$subTaskKey': 'completed'});
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
      print("Error completing habit item: $e");
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
    /* ... unchanged ... */
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
    /* ... unchanged ... */
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
      print("Error completing task: $e");
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
    /* ... unchanged ... */
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
    /* ... unchanged ... */
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: const Color(0xFF7ED6A8)),
          SizedBox(height: 20),
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
} // End of _HomeScreenState
