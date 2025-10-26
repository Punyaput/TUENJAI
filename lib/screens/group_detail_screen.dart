// lib/screens/group_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/background_circles.dart';
import './create_task_screen.dart'; // Used for creating AND editing
import './group_settings_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  String? _userRole;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final List<String> _dayLabelsShort = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
  final Map<String, String> _userNameCache = {}; // Cache usernames

  // --- NEW: Task Type Colors (from home_screen) ---
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
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && mounted) {
          setState(() {
            _userRole = userDoc.data()?['role'];
          });
        }
        // ignore: empty_catches
      } catch (e) {}
    }
  }

  // --- NEW: _parseTimeString Helper (from home_screen) ---
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
          for (var doc in querySnapshot.docs) {
            final name = doc.data()['username'] ?? 'Unknown User';
            _userNameCache[doc.id] = name;
            names[doc.id] = name;
          }
        }
      } catch (e) {
        // Ignore individual fetch errors
      }
    }
    for (String id in userIds) {
      names.putIfAbsent(id, () => _userNameCache[id] ?? 'Unknown User');
    }
    return names;
  }
  // --- End Username Helpers ---

  void _createTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTaskScreen(groupId: widget.groupId),
      ),
    );
  }

  // Navigate to CreateTaskScreen for editing Appointments/Countdowns/Habits (metadata)
  void _editTask(Map<String, dynamic> taskData, String taskId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTaskScreen(
          groupId: widget.groupId,
          existingTaskData: taskData, // Pass existing data
          taskId: taskId, // Pass ID to indicate editing
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.groupName,
          style: const TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            color: Color(0xFF374151),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_userRole == 'caretaker')
            IconButton(
              icon: const Icon(Icons.settings, color: Color(0xFF374151)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GroupSettingsScreen(
                      groupId: widget.groupId,
                      initialGroupName: widget.groupName,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10), // Reduced top padding
                  // --- UI CHANGE: Wrap list in a Card ---
                  Expanded(child: _buildTasksListStream(screenWidth)),
                  // --- End UI Change ---
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _userRole == 'caretaker'
          ? FloatingActionButton(
              onPressed: _createTask,
              backgroundColor: _appointmentColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTasksListStream(double screenWidth) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final todayWeekday = today.weekday;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyTasksList();
        }

        final taskDocs = snapshot.data!.docs;
        final currentUser = FirebaseAuth.instance.currentUser;

        // --- REFACTORED: Categorize Tasks (from home_screen) ---
        List<Map<String, dynamic>> pendingToday = [];
        List<Map<String, dynamic>> overdueToday = [];
        List<Map<String, dynamic>> completedToday = [];
        List<Map<String, dynamic>> todaysCountdowns = [];
        List<Map<String, dynamic>> activeHabits = [];
        List<Map<String, dynamic>> upcoming = [];
        Set<String> usersToFetch = {};
        // --- End Refactor ---

        for (var doc in taskDocs) {
          final task = doc.data() as Map<String, dynamic>;
          final taskId = doc.id;
          final type = task['taskType'] ?? '';
          final status = task['status'] ?? '';
          final assignedTo =
              (task['assignedTo'] as List?)?.cast<String>() ?? [];
          usersToFetch.addAll(assignedTo);
          final completedBy = task['completedBy'] as String?;
          if (completedBy != null) usersToFetch.add(completedBy);

          final Timestamp? ts = task['taskDateTime']; // For Appt/Countdown
          DateTime? taskDate; // Has time
          DateTime? taskDayOnly; // Date only
          if (ts != null) {
            taskDate = ts.toDate();
            taskDayOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);
          }

          bool isToday =
              taskDayOnly != null && taskDayOnly.isAtSameMomentAs(today);

          // Filter out tasks not relevant to CareReceiver if needed
          bool relevantForReceiver = true;
          if (_userRole == 'carereceiver') {
            relevantForReceiver = false;
            if (type == 'appointment' &&
                assignedTo.contains(currentUser?.uid)) {
              relevantForReceiver = true;
            }
            if (type == 'habit_schedule' &&
                assignedTo.contains(currentUser?.uid)) {
              relevantForReceiver = true;
            }
            if (type == 'countdown') relevantForReceiver = true;
            if (!relevantForReceiver) continue;
          }

          // --- REFACTORED: Categorization Logic ---
          if (type == 'habit_schedule') {
            // Add to main habit list (for Caretaker)
            if (_userRole == 'caretaker') {
              activeHabits.add({'id': taskId, 'data': task});
            }

            // Extract today's items
            final schedule =
                (task['schedule'] as Map?)?.cast<String, List<dynamic>>() ?? {};
            final tasksForTodayDynamic = schedule[todayWeekday.toString()];
            if (tasksForTodayDynamic != null) {
              final List<Map<String, String>> tasksForToday =
                  tasksForTodayDynamic
                      .cast<Map<dynamic, dynamic>>()
                      .map((item) => item.cast<String, String>())
                      .toList();
              final completionHistory =
                  (task['completionHistory'] as Map?)?.cast<String, String>() ??
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
                  'id': taskId, // Main habit doc ID
                  'groupId': widget.groupId,
                  'subTaskKey': subTaskKey,
                  'time': subTaskTimeStr,
                  'title': subTaskTitle,
                  'assignedTo': assignedTo,
                  'isCompleted': isCompleted,
                  'data': task,
                };

                if (isCompleted) {
                  completedToday.add(itemData);
                } else {
                  // Check if overdue
                  final subTaskDateTime = _parseTimeString(
                    subTaskTimeStr,
                    today,
                  );
                  if (subTaskDateTime != null &&
                      subTaskDateTime.isBefore(now)) {
                    overdueToday.add(itemData);
                  } else {
                    pendingToday.add(itemData);
                  }
                }
              }
            }
          } else if (type == 'appointment') {
            final itemData = {
              'type': 'appointment',
              'id': taskId,
              'groupId': widget.groupId,
              'data': task,
              'isCompleted': status == 'completed',
            };

            if (isToday) {
              if (status == 'completed') {
                completedToday.add(itemData);
              } else if (taskDate != null && taskDate.isBefore(now)) {
                overdueToday.add(itemData);
              } else {
                pendingToday.add(itemData);
              }
            } else if (taskDate != null && taskDate.isAfter(today)) {
              upcoming.add(itemData);
            } else if (taskDate != null &&
                taskDate.isBefore(today) &&
                status == 'pending') {
              overdueToday.add(itemData);
            }
          } else if (type == 'countdown') {
            if (taskDate == null) continue;
            final itemData = {
              'type': 'countdown',
              'id': taskId,
              'groupId': widget.groupId,
              'data': task,
            };
            final int days = taskDayOnly!.difference(today).inDays;
            if (days == 0) {
              todaysCountdowns.add(itemData);
            } else if (days > 0) {
              upcoming.add(itemData);
            } else if (days < 0) {
              // <-- ADD THIS
              overdueToday.add(itemData);
            }
          }
        }
        // --- End Categorization ---

        // Fetch usernames
        _getUsernames(usersToFetch.toList());

        // Sort categories
        pendingToday.sort(_sortTaskItems);
        overdueToday.sort(_sortTaskItems);
        completedToday.sort(_sortCompletedItems);
        todaysCountdowns.sort(_sortUpcomingItems);
        upcoming.sort(_sortUpcomingItems);
        activeHabits.sort(
          (a, b) =>
              (a['data']['title'] ?? '').compareTo(b['data']['title'] ?? ''),
        );

        // Check for empty state
        bool allEmpty =
            pendingToday.isEmpty &&
            overdueToday.isEmpty &&
            completedToday.isEmpty &&
            todaysCountdowns.isEmpty &&
            activeHabits.isEmpty &&
            upcoming.isEmpty;

        if (_userRole == 'carereceiver') {
          // Receiver doesn't see main habit list
          allEmpty =
              pendingToday.isEmpty &&
              overdueToday.isEmpty &&
              completedToday.isEmpty &&
              todaysCountdowns.isEmpty &&
              upcoming.isEmpty;
        }

        if (allEmpty) return _buildEmptyTasksList();

        // --- Build Sectioned ListView ---
        return ListView(
          // Padding for FAB
          padding: const EdgeInsets.only(bottom: 120, top: 8),
          children: [
            // --- Pending Section ---
            if (pendingToday.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'วันนี้ (รอดำเนินการ)',
                      Icons.radio_button_unchecked,
                      _pendingColor,
                      screenWidth,
                    ),
                    ...pendingToday.map(
                      (item) => _buildDashboardItemCardWithControls(
                        item,
                        screenWidth,
                      ),
                    ),
                    const SizedBox(height: 8), // Padding inside card bottom
                  ],
                ),
              ),

            // --- Overdue Section ---
            if (overdueToday.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'ผ่านไปแล้ว', // Updated name
                      Icons.warning_amber_rounded,
                      _overdueColor,
                      screenWidth,
                    ),
                    ...overdueToday.map(
                      (item) => _buildDashboardItemCardWithControls(
                        item,
                        screenWidth,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // --- Completed Section ---
            if (completedToday.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'วันนี้ (เสร็จสิ้น)',
                      Icons.check_circle,
                      _completedColor,
                      screenWidth,
                    ),
                    ...completedToday.map(
                      (item) => _buildDashboardItemCardWithControls(
                        item,
                        screenWidth,
                        isCompleted: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // --- Today's Countdowns Section ---
            if (todaysCountdowns.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'กิจกรรมวันนี้!',
                      Icons.celebration_rounded,
                      _todayEventColor,
                      screenWidth,
                    ),
                    ...todaysCountdowns.map(
                      (item) => _buildCountdownCardWithControls(
                        item['data'],
                        item['id'],
                        screenWidth,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // --- Active Habit Schedules Section (Caretaker Only) ---
            if (_userRole == 'caretaker' && activeHabits.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'กิจวัตรที่ใช้งานอยู่',
                      Icons.calendar_month,
                      _habitColor,
                      screenWidth,
                    ),
                    ...activeHabits.map(
                      (item) => _buildHabitScheduleCardWithControls(
                        item['data'],
                        item['id'],
                        screenWidth,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),

            // --- Upcoming Section ---
            if (upcoming.isNotEmpty)
              Card(
                // Wrap section in Card
                elevation: 1.5,
                shadowColor: Colors.black.withValues(alpha: 0.06),
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                child: Column(
                  children: [
                    _buildSectionHeader(
                      'งานที่กำลังมาถึง',
                      Icons.hourglass_bottom,
                      Colors.grey.shade600,
                      screenWidth,
                    ),
                    ...upcoming.map(
                      (item) => item['type'] == 'countdown'
                          ? _buildCountdownCardWithControls(
                              item['data'],
                              item['id'],
                              screenWidth,
                            )
                          : _buildAppointmentCardWithControls(
                              item['data'],
                              item['id'],
                              screenWidth,
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
          ], // End ListView children
        );
      },
    );
  }

  // --- Sorting Helpers (Copied from home_screen) ---
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
    Timestamp? completedA = a['data']?['completedAt'];
    Timestamp? completedB = b['data']?['completedAt'];

    if (a['type'] == 'habit_item') completedA = null;
    if (b['type'] == 'habit_item') completedB = null;

    if (completedA != null && completedB != null) {
      return completedB.compareTo(completedA); // Newest completed first
    }
    if (completedA != null) return -1;
    if (completedB != null) return 1;

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

  // --- Helper to build section headers ---
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

  // --- REFACTORED WIDGETS FOR TASK CARDS (with Controls) ---

  /// Builds a card for Habits and Appointments (Today, Overdue, Completed)
  Widget _buildDashboardItemCardWithControls(
    Map<String, dynamic> item,
    double screenWidth, {
    bool isCompleted = false,
  }) {
    final String type = item['type'] ?? 'unknown';
    String title = 'ไม่มีชื่อ';
    String time = '--:--';
    String docId = item['id'];
    Map<String, dynamic> taskData = item['data'];
    List<String> assignedToIds = [];
    IconData itemIcon = Icons.task_alt;
    Color itemColor = Colors.grey;
    String? completedByName;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool isOverdue = false;

    if (type == 'habit_item') {
      title = item['title'] ?? 'กิจวัตร';
      time = item['time'] ?? '--:--';
      assignedToIds = (item['assignedTo'] as List?)?.cast<String>() ?? [];
      itemIcon = Icons.calendar_month_outlined; // <-- Habit icon
      final subTaskDateTime = _parseTimeString(time, today);
      if (!isCompleted &&
          subTaskDateTime != null &&
          subTaskDateTime.isBefore(now)) {
        isOverdue = true;
      }
      itemColor = isCompleted
          ? _completedColor
          : (isOverdue ? _overdueColor : _habitColor);
      final String? completerId =
          item['data']?['completionHistory']?[item['subTaskKey'] + '_by'];
      if (completerId != null) completedByName = _userNameCache[completerId];
    } else if (type == 'appointment') {
      taskData = item['data']; // Ensure taskData is set
      docId = item['id']; // Ensure docId is set
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
        if (completerId != null) completedByName = _userNameCache[completerId];
      }
    } else if (type == 'countdown') {
      taskData = item['data']; // Ensure taskData is set
      docId = item['id']; // Ensure docId is set
      title = taskData['title'] ?? 'นับถอยหลัง';
      assignedToIds = [];
      itemIcon = Icons.hourglass_bottom; // <-- Countdown icon
      isOverdue = true;
      itemColor = _overdueColor;

      final Timestamp? ts = taskData['taskDateTime'];
      if (ts != null) {
        final dt = ts.toDate();
        time = DateFormat('d MMM y', 'th').format(dt); // <-- Shows Date
      } else {
        time = 'ไม่มีวันที่';
      }
    }

    return InkWell(
      onLongPress: _userRole == 'caretaker'
          ? () => _showDeleteTaskDialog(context, docId, title)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
        padding: const EdgeInsets.only(left: 16, top: 10, bottom: 10, right: 8),
        decoration: BoxDecoration(
          color: isCompleted
              ? Colors.white.withValues(alpha: 0.8)
              : Colors.white,
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
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : null,
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
                        detailText =
                            'กิจกรรมผ่านไปแล้ว'; // <-- Countdown detail
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
            Text(
              time,
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                // --- UPDATED FONT SIZE ---
                fontSize: (time.contains(' ') || type == 'countdown') ? 13 : 15,
                // --- END UPDATE ---
                color: itemColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Controls only for Caretaker
            if (_userRole == 'caretaker' &&
                !isCompleted &&
                (type == 'appointment' || type == 'countdown'))
              IconButton(
                icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'แก้ไขงาน',
                onPressed: () => _editTask(taskData, docId),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds an "Upcoming" Appointment card
  Widget _buildAppointmentCardWithControls(
    Map<String, dynamic> task,
    String taskId,
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
    return InkWell(
      onLongPress: _userRole == 'caretaker'
          ? () => _showDeleteTaskDialog(context, taskId, taskTitle)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
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
            if (_userRole == 'caretaker')
              IconButton(
                icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'แก้ไขงาน',
                onPressed: () => _editTask(task, taskId),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a Countdown card
  Widget _buildCountdownCardWithControls(
    Map<String, dynamic> task,
    String taskId,
    double screenWidth,
  ) {
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
    final cardColor = days == 0 ? _todayEventColor : _countdownColor;

    return InkWell(
      onLongPress: _userRole == 'caretaker'
          ? () => _showDeleteTaskDialog(context, taskId, taskTitle)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
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
            if (_userRole == 'caretaker')
              IconButton(
                icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'แก้ไขงาน',
                onPressed: () => _editTask(task, taskId),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds a Habit Schedule (management) card
  Widget _buildHabitScheduleCardWithControls(
    Map<String, dynamic> task,
    String taskId,
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

    return InkWell(
      onLongPress: _userRole == 'caretaker'
          ? () => _showDeleteTaskDialog(context, taskId, title)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
        padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
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
                  FutureBuilder<Map<String, String>>(
                    future: _getUsernames(assigned),
                    builder: (context, snapshot) {
                      String assignSum = 'มอบหมายให้ ${assigned.length} คน';
                      if (snapshot.connectionState == ConnectionState.done &&
                          snapshot.hasData &&
                          snapshot.data != null &&
                          snapshot.data!.values.isNotEmpty) {
                        assignSum =
                            'มอบหมายให้: ${snapshot.data!.values.join(', ')}';
                        if (assignSum.length > 40) {
                          assignSum = 'มอบหมายให้ ${assigned.length} คน';
                        }
                      } else if (assigned.isEmpty) {
                        assignSum = 'ไม่ได้มอบหมาย';
                      }
                      return Text(
                        assignSum,
                        style: const TextStyle(
                          fontFamily: 'NotoLoopedThaiUI',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      );
                    },
                  ),
                ],
              ),
            ),
            if (_userRole == 'caretaker')
              IconButton(
                icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'แก้ไขกิจวัตร',
                onPressed: () => _editTask(task, taskId),
              ),
          ],
        ),
      ),
    );
  }

  // --- End Refactored Widgets ---

  Widget _buildEmptyTasksList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'ยังไม่มีงาน',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          if (_userRole == 'caretaker')
            const Text(
              'แตะปุ่ม + เพื่อสร้างงานใหม่',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteTask(String taskId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('tasks')
          .doc(taskId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบงานเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showDeleteTaskDialog(
    BuildContext context,
    String taskId,
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
            'ลบงาน',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'คุณต้องการลบงาน "$taskTitle" ใช่หรือไม่? (การดำเนินการนี้จะลบงานหลักทั้งหมด)',
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
                _deleteTask(taskId);
              },
              child: const Text(
                'ลบ',
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
} // End of _GroupDetailScreenState
