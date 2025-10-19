// lib/screens/edit_schedule_screen.dart

import 'package:flutter/material.dart';
// Removed Firestore/Auth imports
import 'package:intl/intl.dart'; // Still needed for formatting time in dialog

class EditScheduleScreen extends StatefulWidget {
  final Map<String, List<Map<String, String>>> initialSchedule;
  // Removed groupId and taskId

  const EditScheduleScreen({
    super.key,
    required this.initialSchedule,
    // Removed groupId and taskId
  });

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  // Local state to manage edits
  late Map<String, List<Map<String, String>>> _currentSchedule;
  final List<String> _dayLabels = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];
  final List<String> _fullDayNames = [
    'วันจันทร์',
    'วันอังคาร',
    'วันพุธ',
    'วันพฤหัสบดี',
    'วันศุกร์',
    'วันเสาร์',
    'วันอาทิตย์',
  ];
  // Removed _isSaving state

  @override
  void initState() {
    super.initState();
    // Deep copy the initial schedule to allow local modifications
    _currentSchedule = Map.from(widget.initialSchedule).map(
      (key, value) => MapEntry(
        key,
        List<Map<String, String>>.from(
          value.map((item) => Map<String, String>.from(item)),
        ),
      ),
    );
    // Ensure all day keys '1' through '7' exist
    for (int i = 1; i <= 7; i++) {
      _currentSchedule.putIfAbsent(i.toString(), () => []);
    }
  }

  // Add a new timed task for a specific day
  void _addTaskForDay(int dayIndex) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext context) {
        final timeController = TextEditingController();
        final titleController = TextEditingController();
        TimeOfDay? time = TimeOfDay.now();
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'เพิ่มรายการสำหรับ ${_fullDayNames[dayIndex]}',
                style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: Text(
                      time?.format(context) ?? 'เลือกเวลา',
                      style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                    ),
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: time ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          time = picked;
                          timeController.text = time!.format(context);
                        });
                      }
                    },
                  ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่องาน (เช่น ทานยา)',
                      labelStyle: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                    ),
                    style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: const Text(
                    'เพิ่ม',
                    style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                  ),
                  onPressed: () {
                    if (time != null &&
                        titleController.text.trim().isNotEmpty) {
                      Navigator.of(context).pop({
                        'time': time,
                        'title': titleController.text.trim(),
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('กรุณากรอกเวลาและชื่องาน'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
    // Add the task if data was returned from dialog
    if (result != null &&
        result['time'] is TimeOfDay &&
        result['title'] is String) {
      final selectedTime = result['time'];
      final taskTitle = result['title'];
      final String formattedTime =
          '${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}';
      final String dayKey = (dayIndex + 1).toString();
      setState(() {
        _currentSchedule[dayKey]!.add({
          'time': formattedTime,
          'title': taskTitle!,
        });
        _currentSchedule[dayKey]!.sort(
          (a, b) => (a['time'] ?? '99').compareTo(b['time'] ?? '99'),
        );
      });
    } // Sort by time
  }

  // Remove a task from the schedule
  void _removeTask(int dayIndex, int taskIndex) {
    final String dayKey = (dayIndex + 1).toString();
    if (_currentSchedule.containsKey(dayKey) &&
        taskIndex >= 0 &&
        taskIndex < _currentSchedule[dayKey]!.length) {
      setState(() {
        _currentSchedule[dayKey]!.removeAt(taskIndex);
      });
    }
  }

  // --- REMOVED _saveSchedule function ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'แก้ไขตารางเวลาประจำสัปดาห์',
          style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
        ),
        actions: [
          // --- UPDATED Save Button: Pops with result ---
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'บันทึก',
            onPressed: () {
              // Pop and return the locally edited schedule
              Navigator.pop(context, _currentSchedule);
            },
          ),
        ],
      ),
      // Build the list of expandable day tiles
      body: ListView.builder(
        itemCount: 7, // For Mon-Sun
        itemBuilder: (context, dayIndex) {
          final String dayKey = (dayIndex + 1).toString(); // '1'..'7'
          final List<Map<String, String>> tasksForDay =
              _currentSchedule[dayKey] ?? [];
          return ExpansionTile(
            key: PageStorageKey('day_$dayKey'), // Maintain expansion state
            // Keep expanded if it has tasks or was just edited
            initiallyExpanded: tasksForDay.isNotEmpty,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColorLight,
              child: Text(
                _dayLabels[dayIndex],
                style: TextStyle(
                  color: Theme.of(context).primaryColorDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              _fullDayNames[dayIndex],
              style: const TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${tasksForDay.length} รายการ',
              style: const TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                color: Colors.grey,
              ),
            ),
            childrenPadding: const EdgeInsets.symmetric(
              horizontal: 16.0,
            ), // Indent children
            children: [
              // List tasks or show 'empty' message
              if (tasksForDay.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'ไม่มีรายการสำหรับวันนี้',
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              if (tasksForDay.isNotEmpty)
                ...tasksForDay.asMap().entries.map((entry) {
                  int taskIndex = entry.key;
                  Map<String, String> task = entry.value;
                  return ListTile(
                    dense: true, // Make list items compact
                    title: Text(
                      task['title'] ?? 'ไม่มีชื่อ',
                      style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                    ),
                    leading: Text(
                      task['time'] ?? '--:--',
                      style: const TextStyle(
                        fontFamily: 'NotoLoopedThaiUI',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                      tooltip: 'ลบรายการนี้',
                      onPressed: () => _removeTask(dayIndex, taskIndex),
                    ),
                  );
                }).toList(),

              // "Add Task" button at the bottom of each day's section
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'เพิ่มรายการ',
                    style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                  ),
                  onPressed: () => _addTaskForDay(dayIndex),
                ),
              ),
              // const SizedBox(height: 10), // Padding below add button
            ],
          );
        },
      ),
    );
  }
}
