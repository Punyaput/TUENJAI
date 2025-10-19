// lib/screens/group_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/background_circles.dart';
import './create_task_screen.dart'; // Used for creating AND editing
import './group_settings_screen.dart';
// Removed EditScheduleScreen import, navigation happens via CreateTaskScreen
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

  // --- REMOVED _editHabitSchedule function, logic moved to _editTask ---

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
                      initialGroupName:
                          widget.groupName, // Pass the current group name
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
                  const SizedBox(height: 20),
                  Text(
                    'งานในกลุ่มนี้',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(child: _buildTasksListStream()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _userRole == 'caretaker'
          ? FloatingActionButton(
              onPressed: _createTask,
              backgroundColor: const Color(0xFF2E88F3),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildTasksListStream() {
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
        return ListView.builder(
          itemCount: taskDocs.length,
          itemBuilder: (context, index) {
            final taskDoc = taskDocs[index];
            final task = taskDoc.data() as Map<String, dynamic>;
            final taskId = taskDoc.id;
            final String taskType = task['taskType'] ?? 'appointment';

            Widget card;
            if (taskType == 'habit_schedule') {
              card = _buildHabitScheduleCard(task, taskId);
            } else if (taskType == 'countdown') {
              card = _buildCountdownCard(task, taskId);
            } else {
              // appointment
              card = _buildAppointmentCard(task, taskId);
            }

            // Wrap card in InkWell for long-press delete
            return InkWell(
              onLongPress: _userRole == 'caretaker'
                  ? () => _showDeleteTaskDialog(
                      context,
                      taskId,
                      task['title'] ?? 'งานนี้',
                    )
                  : null,
              child: card,
            );
          },
        );
      },
    );
  }

  // --- Widget for "Appointment" type tasks ---
  Widget _buildAppointmentCard(Map<String, dynamic> task, String taskId) {
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final Timestamp? taskTimestamp = task['taskDateTime'];
    if (taskTimestamp == null)
      return ListTile(title: Text('$taskTitle (Missing Date)'));
    final DateTime taskDate = taskTimestamp.toDate();
    final String status = task['status'] ?? 'pending';
    final bool isCompleted = status == 'completed';
    final String formattedDate = DateFormat('d MMM y', 'th').format(taskDate);
    final String formattedTime = DateFormat('HH:mm').format(taskDate);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.white.withOpacity(0.7) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            color: isCompleted ? const Color(0xFF2E88F3) : Colors.grey,
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
                color: isCompleted ? Colors.grey : Colors.black,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedDate,
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  fontSize: 14,
                  color: isCompleted ? Colors.grey : const Color(0xFF2E88F3),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                formattedTime,
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

  // --- Widget for "Countdown" type tasks ---
  Widget _buildCountdownCard(Map<String, dynamic> task, String taskId) {
    final taskTitle = task['title'] ?? 'ไม่มีชื่องาน';
    final Timestamp? taskTimestamp = task['taskDateTime'];
    if (taskTimestamp == null)
      return ListTile(title: Text('$taskTitle (Missing Date)'));
    final DateTime taskDate = taskTimestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
    final int daysRemaining = targetDay.difference(today).inDays;
    String dayString;
    if (daysRemaining < 0) {
      dayString = 'ผ่านไปแล้ว';
    } else if (daysRemaining == 0) {
      dayString = 'วันนี้!';
    } else {
      dayString = '$daysRemaining วัน';
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7ED6A8), width: 2),
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
          const Icon(Icons.hourglass_bottom, color: Color(0xFF7ED6A8)),
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
            dayString,
            style: const TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: 20,
              color: Color(0xFF7ED6A8),
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

  // --- Widget for "Habit Schedule" summary card ---
  Widget _buildHabitScheduleCard(Map<String, dynamic> task, String taskId) {
    final title = task['title'] ?? 'กิจวัตรประจำสัปดาห์';
    final scheduleMap =
        (task['schedule'] as Map?)?.cast<String, dynamic>() ?? {};
    final assignedToList = (task['assignedTo'] as List?)?.cast<String>() ?? [];
    List<String> activeDayLabels = [];
    for (int i = 1; i <= 7; i++) {
      final dayKey = i.toString();
      final dayTasks = (scheduleMap[dayKey] as List?) ?? [];
      if (dayTasks.isNotEmpty) {
        activeDayLabels.add(_dayLabelsShort[i - 1]);
      }
    }
    final repeatSummary = activeDayLabels.isNotEmpty
        ? 'ทำซ้ำ ${activeDayLabels.join(", ")}'
        : 'ไม่ได้กำหนดวัน';
    final assignedCount = assignedToList.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 16, top: 16, bottom: 16, right: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade100, width: 2),
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
          Icon(Icons.calendar_month, color: Colors.purple[300]),
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
                  repeatSummary,
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
          // --- UPDATED: Edit Button navigates to CreateTaskScreen ---
          if (_userRole == 'caretaker')
            IconButton(
              icon: Icon(Icons.edit_note, color: Colors.grey[600], size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: 'แก้ไขกิจวัตร',
              onPressed: () =>
                  _editTask(task, taskId), // Use general edit function
            ),
        ],
      ),
    );
  }

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

  // --- Delete Task Functions (Unchanged) ---
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
