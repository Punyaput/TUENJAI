// lib/screens/group_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/background_circles.dart';
import './create_task_screen.dart'; // Used for creating AND editing
import './group_settings_screen.dart';
import './edit_schedule_screen.dart'; // Needed if you add a direct edit schedule button
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

  // --- Task Type Colors (Example - Should match HomeScreen) ---
  final Color _appointmentColor = const Color(0xFF2E88F3); // Blue
  final Color _countdownColor = const Color(0xFF7ED6A8); // Green
  final Color _habitColor = Colors.purple.shade300; // Purple
  final Color _completedColor = Colors.green.shade600; // Completed Green

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
      } catch (e) {
        print("Error fetching user role: $e");
      }
    }
  }

  // --- Username Fetching Helpers (Copied from HomeScreen) ---
  Future<String> _getUsername(String userId) async {
    if (_userNameCache.containsKey(userId)) return _userNameCache[userId]!;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (userDoc.exists) {
        final name = userDoc.data()?['username'] ?? 'Unknown User';
        _userNameCache[userId] = name;
        return name;
      }
    } catch (e) {
      print("Error getting username for $userId: $e");
    }
    return 'Unknown User';
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
            final name = doc.data()['username'] ?? 'Unknown User';
            _userNameCache[doc.id] = name;
            names[doc.id] = name;
          }
        }
      } catch (e) {
        print("Error getting usernames: $e");
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
                  Expanded(
                    child: _buildTasksListStream(screenWidth),
                  ), // Pass screenWidth
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

  // --- UPDATED: Builds categorized list ---
  Widget _buildTasksListStream(double screenWidth) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayKey = DateFormat('yyyy-MM-dd').format(todayStart);
    final todayWeekday = todayStart.weekday;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('tasks')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return _buildEmptyTasksList();

        final taskDocs = snapshot.data!.docs;
        final currentUser = FirebaseAuth.instance.currentUser;

        // --- Categorize Tasks ---
        List<Map<String, dynamic>> pendingItems = [];
        List<Map<String, dynamic>> upcomingCountdowns = [];
        List<Map<String, dynamic>> activeHabits = [];
        List<Map<String, dynamic>> completedItems = [];
        Set<String> usersToFetch = {};

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
          DateTime? taskDate;
          DateTime? taskDayOnly;
          if (ts != null) {
            taskDate = ts.toDate();
            taskDayOnly = DateTime(taskDate.year, taskDate.month, taskDate.day);
          }

          bool isToday =
              taskDayOnly != null && taskDayOnly.isAtSameMomentAs(todayStart);
          bool isFuture =
              taskDayOnly != null && taskDayOnly.isAfter(todayStart);
          bool isPast = taskDayOnly != null && taskDayOnly.isBefore(todayStart);

          // Filter out tasks not relevant to CareReceiver if needed
          bool relevantForReceiver = true;
          if (_userRole == 'carereceiver') {
            relevantForReceiver = false;
            if (type == 'appointment' && assignedTo.contains(currentUser?.uid))
              relevantForReceiver = true;
            if (type == 'habit_schedule' &&
                assignedTo.contains(currentUser?.uid))
              relevantForReceiver = true;
            if (type == 'countdown') relevantForReceiver = true;
            if (!relevantForReceiver) continue;
          }

          // Categorize for Display
          if (type == 'habit_schedule') {
            activeHabits.add({'id': taskId, 'data': task});
            // Also extract today's items for completion check (only needed for Caretaker completed section)
            if (_userRole == 'caretaker') {
              final schedule =
                  (task['schedule'] as Map?)?.cast<String, List<dynamic>>() ??
                  {};
              final tasksForTodayDynamic = schedule[todayWeekday.toString()];
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
                  final subTaskKey = '${todayKey}_${subTaskTime}_$subTaskTitle';
                  final isCompleted =
                      completionHistory[subTaskKey] == 'completed';
                  // Add item data structure similar to HomeScreen
                  final itemData = {
                    'type': 'habit_item',
                    'id': taskId,
                    'subTaskKey': subTaskKey,
                    'time': subTaskTime,
                    'title': subTaskTitle,
                    'assignedTo': assignedTo,
                    'isCompleted': isCompleted,
                    'data': task,
                  };
                  if (isCompleted) {
                    completedItems.add(itemData);
                  } else {
                    pendingItems.add(itemData);
                  } // Caretaker sees pending habits here
                }
              }
            }
          } else if (type == 'appointment') {
            if (status == 'completed') {
              final Timestamp? completedTs = task['completedAt'];
              bool showCompleted = false;
              if (_userRole == 'caretaker') {
                if (completedTs != null) {
                  final completedDate = completedTs.toDate();
                  // Show completed today or in the past X days? For now, show all.
                  showCompleted = true;
                } else {
                  showCompleted = true; // Show even if timestamp missing
                }
              }
              if (showCompleted) {
                completedItems.add({
                  'type': 'appointment',
                  'id': taskId,
                  'data': task,
                  'isCompleted': true,
                });
              }
            } else if (status == 'pending') {
              // Add all pending (today, future, past/overdue) to the list
              pendingItems.add({
                'type': 'appointment',
                'id': taskId,
                'data': task,
                'isCompleted': false,
              });
            }
          } else if (type == 'countdown') {
            if (isToday || isFuture) {
              upcomingCountdowns.add({
                'type': 'countdown',
                'id': taskId,
                'data': task,
              });
            } else if (isPast) {
              // Add past countdowns to completed visually
              if (_userRole == 'caretaker') {
                completedItems.add({
                  'type': 'countdown',
                  'id': taskId,
                  'data': task,
                  'isCompleted': true,
                });
              }
            }
          }
        }

        // Fetch usernames
        _getUsernames(usersToFetch.toList());

        // Sort categories
        pendingItems.sort(_sortPendingItems);
        completedItems.sort(_sortCompletedItems);
        upcomingCountdowns.sort(_sortUpcomingItems);
        activeHabits.sort(
          (a, b) =>
              (a['data']['title'] ?? '').compareTo(b['data']['title'] ?? ''),
        );

        bool allEmpty =
            pendingItems.isEmpty &&
            upcomingCountdowns.isEmpty &&
            activeHabits.isEmpty &&
            completedItems.isEmpty;
        if (_userRole == 'carereceiver') {
          // Receiver doesn't see completed section here
          allEmpty =
              pendingItems.isEmpty &&
              upcomingCountdowns.isEmpty &&
              activeHabits.isEmpty;
        }

        if (allEmpty) return _buildEmptyTasksList();

        // --- Build Sectioned ListView ---
        return ListView(
          padding: const EdgeInsets.only(bottom: 120), // Padding for FAB
          children: [
            // --- Pending Section ---
            if (pendingItems.isNotEmpty) ...[
              _buildSectionHeader(
                'รอดำเนินการ',
                Icons.pending_actions_outlined,
                Colors.orange,
                screenWidth,
              ),
              ...pendingItems
                  .where((item) {
                    // Filter receiver view *again* just to be safe
                    if (_userRole == 'carereceiver' &&
                        item['type'] == 'habit_item')
                      return false; // Receiver sees habits on Home
                    return true;
                  })
                  .map((item) {
                    Widget card;
                    if (item['type'] == 'appointment') {
                      card = _buildAppointmentCard(item['data'], item['id']);
                    } else {
                      // habit_item (only for caretaker view)
                      // --- CORRECTED CALL ---
                      card = _buildHabitItemCardReadOnly(item, screenWidth);
                    }
                    return InkWell(
                      onLongPress: _userRole == 'caretaker'
                          ? () => _showDeleteTaskDialog(
                              context,
                              item['id'],
                              item['data']?['title'] ??
                                  item['title'] ??
                                  'งานนี้',
                            )
                          : null,
                      child: card,
                    );
                  })
                  .toList(),
            ],

            // --- Active Habit Schedules Section ---
            if (activeHabits.isNotEmpty) ...[
              _buildSectionHeader(
                'กิจวัตร',
                Icons.calendar_month,
                _habitColor,
                screenWidth,
              ),
              ...activeHabits
                  .map(
                    (item) => InkWell(
                      onLongPress: _userRole == 'caretaker'
                          ? () => _showDeleteTaskDialog(
                              context,
                              item['id'],
                              item['data']?['title'] ?? 'งานนี้',
                            )
                          : null,
                      child: _buildHabitScheduleCard(item['data'], item['id']),
                    ),
                  )
                  .toList(),
            ],

            // --- Upcoming Countdowns Section ---
            if (upcomingCountdowns.isNotEmpty) ...[
              _buildSectionHeader(
                'การนับถอยหลัง',
                Icons.hourglass_bottom,
                _countdownColor,
                screenWidth,
              ),
              ...upcomingCountdowns
                  .map(
                    (item) => InkWell(
                      onLongPress: _userRole == 'caretaker'
                          ? () => _showDeleteTaskDialog(
                              context,
                              item['id'],
                              item['data']?['title'] ?? 'งานนี้',
                            )
                          : null,
                      child: _buildCountdownCard(item['data'], item['id']),
                    ),
                  )
                  .toList(),
            ],

            // --- Completed Section (Caretaker Only) ---
            if (_userRole == 'caretaker' && completedItems.isNotEmpty) ...[
              _buildSectionHeader(
                'เสร็จสิ้นแล้ว / ผ่านไปแล้ว',
                Icons.check_circle_outline,
                _completedColor,
                screenWidth,
              ),
              ...completedItems.map((item) {
                Widget card;
                if (item['type'] == 'appointment') {
                  card = _buildAppointmentCard(item['data'], item['id']);
                } // Shows completed style
                else if (item['type'] == 'habit_item') {
                  card = _buildHabitItemCardReadOnly(
                    item,
                    screenWidth,
                    isCompleted: true,
                  );
                } // Shows completed style
                else {
                  card = _buildCountdownCard(item['data'], item['id']);
                } // Past countdown
                // Make completed items non-editable, only deletable
                return InkWell(
                  onLongPress: _userRole == 'caretaker'
                      ? () => _showDeleteTaskDialog(
                          context,
                          item['id'],
                          item['data']?['title'] ?? item['title'] ?? 'งานนี้',
                        )
                      : null,
                  child: card,
                );
              }).toList(),
            ],
          ],
        );
      },
    );
  }

  // --- Sorting Helpers ---
  int _sortPendingItems(Map<String, dynamic> a, Map<String, dynamic> b) {
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

  // --- Helper to build section headers ---
  Widget _buildSectionHeader(
    String title,
    IconData icon,
    Color color,
    double screenWidth,
  ) {
    /* ... unchanged ... */
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
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

  // --- WIDGETS FOR TASK CARDS ---
  Widget _buildAppointmentCard(Map<String, dynamic> task, String taskId) {
    /* ... unchanged ... includes edit button */
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final Timestamp? ts = task['taskDateTime'];
    final dt = ts?.toDate();
    final status = task['status'] ?? 'pending';
    final isCompleted = status == 'completed';
    final date = dt != null ? DateFormat('d MMM y', 'th').format(dt) : '-';
    final time = dt != null ? DateFormat('HH:mm').format(dt) : '-';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withOpacity(0.7) : Colors.white,
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
          Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isCompleted ? _appointmentColor : Colors.grey,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              taskTitle,
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                decoration: isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: isCompleted ? Colors.grey : Colors.black87,
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
                  color: isCompleted ? Colors.grey : _appointmentColor,
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
          if (_userRole == 'caretaker' && !isCompleted)
            IconButton(
              icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'แก้ไขงาน',
              onPressed: () => _editTask(task, taskId),
            ),
        ],
      ),
    );
  }

  Widget _buildCountdownCard(Map<String, dynamic> task, String taskId) {
    /* ... unchanged ... includes edit button */
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
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
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
    );
  }

  Widget _buildHabitScheduleCard(Map<String, dynamic> task, String taskId) {
    /* ... unchanged ... includes edit button */
    final title = task['title'] ?? 'กิจวัตร';
    final schedule = (task['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final assigned = (task['assignedTo'] as List?)?.cast<String>() ?? [];
    List<String> days = [];
    for (int i = 1; i <= 7; i++) {
      if ((schedule[i.toString()] as List?)?.isNotEmpty ?? false)
        days.add(_dayLabelsShort[i - 1]);
    }
    final repeat = days.isNotEmpty ? 'ทำซ้ำ ${days.join(", ")}' : '-';
    final assignedCount = assigned.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
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
                  'มอบหมายให้ $assignedCount คน',
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
    );
  }

  // --- ADDED: Read-Only Card for Individual Habit Items (used in this screen) ---
  Widget _buildHabitItemCardReadOnly(
    Map<String, dynamic> itemData,
    double screenWidth, {
    bool isCompleted = false,
  }) {
    final String title = itemData['title'] ?? 'กิจวัตร';
    final String time = itemData['time'] ?? '--:--';
    final List<String> assignedToIds =
        (itemData['assignedTo'] as List?)?.cast<String>() ?? [];
    String? completedByName; // Fetch if needed
    // If completed, try to find who completed it (more complex, needs data structure change)
    // For now, just show assigned to
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isCompleted ? _completedColor : _habitColor).withOpacity(
            isCompleted ? 0.5 : 0.8,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.calendar_month_outlined,
            color: isCompleted ? _completedColor : _habitColor,
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
                    String detailText = isCompleted
                        ? 'เสร็จสิ้นแล้ว'
                        : 'สำหรับ: ...';
                    if (isCompleted && completedByName != null) {
                      detailText = 'เสร็จสิ้นโดย: $completedByName';
                    } else if (!isCompleted &&
                        snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      detailText =
                          'สำหรับ: ${snapshot.data?.values.join(', ') ?? '?'}';
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
              fontSize: 15,
              color: isCompleted ? _completedColor : _habitColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyTasksList() {
    /* ... unchanged ... */
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
    /* ... unchanged ... */
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
      print("Error deleting task: $e");
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
    /* ... unchanged ... */
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
            'คุณต้องการลบงาน "$taskTitle" ใช่หรือไม่?',
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
