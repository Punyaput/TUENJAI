// lib/screens/create_task_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/custom_button.dart';
import '../widgets/background_circles.dart';
import './edit_schedule_screen.dart'; // Needed for habit editing

enum TaskType { appointment, countdown, habit }

class CreateTaskScreen extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic>? existingTaskData; // Data for editing
  final String? taskId; // ID of task being edited

  const CreateTaskScreen({
    super.key,
    required this.groupId,
    this.existingTaskData,
    this.taskId,
  });

  // Helper to determine if we are in edit mode
  bool get isEditing => existingTaskData != null && taskId != null;

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Map<String, List<Map<String, String>>> _habitSchedule = {}; // Local copy

  TaskType _selectedType = TaskType.appointment; // Default selection

  bool _isLoadingMembers = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _careReceivers = [];
  final Map<String, bool> _selectedReceivers =
      {}; // Tracks assignment selection

  @override
  void initState() {
    super.initState();
    _populateFormForEdit(); // Populate form fields if editing
    _fetchGroupMembers(); // Fetch members after potentially setting selectedType
  }

  // Pre-fill form fields if editing an existing task
  void _populateFormForEdit() {
    if (widget.isEditing && widget.existingTaskData != null) {
      final data = widget.existingTaskData!;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['description'] ?? '';

      // Determine Task Type (Cannot change type when editing)
      final String taskTypeString = data['taskType'] ?? 'appointment';
      if (taskTypeString == 'countdown') {
        _selectedType = TaskType.countdown;
      } else if (taskTypeString == 'habit_schedule') {
        _selectedType = TaskType.habit;
        // Load existing schedule into local state
        final scheduleData = data['schedule'] as Map?;
        if (scheduleData != null) {
          _habitSchedule = scheduleData.map((key, value) {
            // Deep copy and cast the inner list and map items
            final list =
                (value as List?)
                    ?.cast<Map<dynamic, dynamic>>()
                    .map((item) => item.cast<String, String>())
                    .toList() ??
                [];
            return MapEntry(key.toString(), list);
          });
          // Ensure all day keys (1-7) exist, even if list is empty
          for (int i = 1; i <= 7; i++) {
            _habitSchedule.putIfAbsent(i.toString(), () => []);
          }
        }
      } else {
        // Default to appointment
        _selectedType = TaskType.appointment;
      }

      // Pre-fill date/time for appointment/countdown
      if (_selectedType == TaskType.appointment ||
          _selectedType == TaskType.countdown) {
        final Timestamp? ts = data['taskDateTime'];
        if (ts != null) {
          _selectedDate = ts.toDate();
          if (_selectedType == TaskType.appointment) {
            _selectedTime = TimeOfDay.fromDateTime(_selectedDate!);
          }
        }
      }

      // Pre-select assigned members (works for appointment and habit)
      final List<dynamic> assigned = data['assignedTo'] ?? [];
      for (var memberId in assigned) {
        if (memberId is String) {
          _selectedReceivers[memberId] = true; // Mark as selected
        }
      }

      // Trigger a rebuild if needed after initial population
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    // Ensure schedule map has all days even when creating a new habit
    else if (_selectedType == TaskType.habit) {
      for (int i = 1; i <= 7; i++) {
        _habitSchedule.putIfAbsent(i.toString(), () => []);
      }
    }
  }

  // Fetch Care Receiver members from the group
  Future<void> _fetchGroupMembers() async {
    setState(() {
      _isLoadingMembers = true;
    });
    try {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .get();
      if (!groupDoc.exists) throw Exception("Group not found");
      final List<dynamic> memberIds = groupDoc.data()?['members'] ?? [];
      if (memberIds.isEmpty) {
        if (mounted)
          setState(() {
            _isLoadingMembers = false;
          });
        return;
      }

      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .where('role', isEqualTo: 'carereceiver') // Only fetch care receivers
          .get();

      final List<Map<String, dynamic>> receivers = [];
      for (var doc in usersQuery.docs) {
        receivers.add({
          'uid': doc.id,
          'username': doc.data()['username'] ?? 'No Name',
        });
        // Initialize selection state respecting pre-population
        _selectedReceivers.putIfAbsent(doc.id, () => false);
      }
      if (mounted)
        setState(() {
          _careReceivers = receivers;
          _isLoadingMembers = false;
        });
    } catch (e) {
      print("Error fetching members: $e");
      if (mounted)
        setState(() {
          _isLoadingMembers = false;
        });
    }
  }

  // Show Date Picker
  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      // Allow selecting past dates only when editing
      firstDate: widget.isEditing
          ? DateTime(2000)
          : DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Show Time Picker
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  // Navigate to Edit Schedule Screen and receive result
  void _editSchedule() async {
    // Navigate, passing the current schedule state
    final result = await Navigator.push<Map<String, List<Map<String, String>>>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditScheduleScreen(initialSchedule: _habitSchedule),
      ),
    );

    // Update the local schedule if the EditScheduleScreen returned data
    if (result != null && mounted) {
      setState(() {
        _habitSchedule = result;
        print("Schedule Updated locally from EditScreen: $_habitSchedule");
      });
    }
  }

  // Save or Update the Task in Firestore
  Future<void> _saveTask() async {
    // --- Validation ---
    if (_titleController.text.trim().isEmpty) {
      _showError("กรุณาใส่ชื่อ");
      return;
    }
    final assignedTo = _selectedReceivers.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if ((_selectedType == TaskType.appointment ||
            _selectedType == TaskType.habit) &&
        assignedTo.isEmpty) {
      _showError("กรุณาเลือกผู้รับการดูแลอย่างน้อย 1 คน");
      return;
    }

    Map<String, dynamic> taskSpecificData = {};
    String taskTypeString = '';

    // Prepare type-specific data
    switch (_selectedType) {
      case TaskType.appointment:
        if (_selectedDate == null || _selectedTime == null) {
          _showError("กรุณาเลือกวันและเวลา");
          return;
        }
        final dt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        taskTypeString = 'appointment';
        taskSpecificData = {
          'taskDateTime': Timestamp.fromDate(dt),
          'assignedTo': assignedTo,
        };
        break;
      case TaskType.countdown:
        if (_selectedDate == null) {
          _showError("กรุณาเลือกวัน");
          return;
        }
        final dt = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
        );
        taskTypeString = 'countdown';
        taskSpecificData = {
          'taskDateTime': Timestamp.fromDate(dt),
          'assignedTo': [],
        };
        break;
      case TaskType.habit:
        // Schedule itself is updated via _editSchedule() and stored in _habitSchedule
        // Validate only if creating new and schedule is still empty
        if (!widget.isEditing &&
            _habitSchedule.values.every((dayList) => dayList.isEmpty)) {
          _showError("กรุณากำหนดตารางเวลาอย่างน้อย 1 วันโดยกดปุ่มแก้ไข");
          return;
        }
        taskTypeString = 'habit_schedule';
        taskSpecificData = {
          'assignedTo': assignedTo,
          // IMPORTANT: Include the potentially updated schedule
          'schedule': _habitSchedule,
        };
        // Add completionHistory only when CREATING
        if (!widget.isEditing) {
          taskSpecificData['completionHistory'] = {};
        }
        break;
    }
    // --- End Validation ---

    setState(() {
      _isSaving = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not logged in");

      // Common data fields
      final Map<String, dynamic> dataToSave = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'groupId': widget.groupId, // Needed for queries
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': user.uid,
        // Add type-specific data prepared above
        ...taskSpecificData,
      };

      // Get Firestore document reference
      final taskDocRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('tasks')
          .doc(widget.isEditing ? widget.taskId : null); // Use ID if editing

      if (widget.isEditing) {
        // --- UPDATE ---
        // Don't update fields that shouldn't change
        dataToSave.remove('groupId');

        // Remove creation/status fields if they accidentally got in
        dataToSave.remove('createdBy');
        dataToSave.remove('createdAt');
        dataToSave.remove('status');
        dataToSave.remove('taskType'); // Type cannot be changed

        // Don't overwrite completionHistory when editing main details
        if (_selectedType == TaskType.habit) {
          // 'schedule' is included, which is correct
        } else {
          dataToSave.remove('schedule');
          dataToSave.remove('completionHistory');
        }

        print("Updating task ${widget.taskId} with data: $dataToSave");
        await taskDocRef.update(dataToSave);
      } else {
        // --- ADD ---
        dataToSave['createdBy'] = user.uid;
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
        dataToSave['status'] = taskTypeString == 'habit_schedule'
            ? 'active'
            : 'pending';
        dataToSave['taskType'] = taskTypeString; // Set type only on creation

        print("Adding new task with data: $dataToSave");
        await taskDocRef.set(dataToSave);
      }

      if (mounted) {
        Navigator.pop(context);
      } // Go back after success
    } catch (e) {
      print("Error saving/updating task: $e");
      _showError("เกิดข้อผิดพลาด: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      // --- UPDATE: Use resizeToAvoidBottomInset: true ---
      // This is the default and works best with SingleChildScrollView
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF374151)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.isEditing ? 'แก้ไขงาน' : 'สร้างงานใหม่',
          style: const TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            color: Color(0xFF374151),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              bottom: -screenWidth * 0.5, // Keep low
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),

            // --- UPDATE: Use LayoutBuilder + ConstrainedBox ---
            LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: screenWidth * 0.1,
                    right: screenWidth * 0.1,
                    // Use keyboard padding here
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      // Force the column to be AT LEAST as tall as the viewport
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment
                            .spaceBetween, // Push content and button apart
                        children: [
                          // --- Top Content Column ---
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              SizedBox(height: screenWidth * 0.05),
                              // Task Type Selector (disabled when editing)
                              AbsorbPointer(
                                absorbing: widget.isEditing,
                                child: Opacity(
                                  opacity: widget.isEditing ? 0.5 : 1.0,
                                  child: SegmentedButton<TaskType>(
                                    // --- REPLACED SEGMENTS ---
                                    segments: const [
                                      ButtonSegment(
                                        value: TaskType.appointment,
                                        // Only show the icon, wrapped in a Tooltip
                                        icon: Tooltip(
                                          message:
                                              'นัดหมาย', // Text appears on long-press
                                          child: Icon(Icons.event_available),
                                        ),
                                        // Remove the 'label' property
                                      ),
                                      ButtonSegment(
                                        value: TaskType.countdown,
                                        icon: Tooltip(
                                          message: 'นับถอยหลัง',
                                          child: Icon(Icons.hourglass_bottom),
                                        ),
                                        // Remove the 'label' property
                                      ),
                                      ButtonSegment(
                                        value: TaskType.habit,
                                        icon: Tooltip(
                                          message: 'กิจวัตร',
                                          child: Icon(Icons.calendar_month),
                                        ),
                                        // Remove the 'label' property
                                      ),
                                    ],
                                    // --- END REPLACEMENT ---
                                    selected: {_selectedType},
                                    onSelectionChanged: widget.isEditing
                                        ? null
                                        : (Set<TaskType> newSelection) {
                                            setState(() {
                                              _selectedType =
                                                  newSelection.first;
                                              if (_selectedType ==
                                                      TaskType.habit &&
                                                  _habitSchedule.isEmpty) {
                                                for (int i = 1; i <= 7; i++) {
                                                  _habitSchedule.putIfAbsent(
                                                    i.toString(),
                                                    () => [],
                                                  );
                                                }
                                              }
                                            });
                                          },
                                  ),
                                ),
                              ),
                              SizedBox(height: screenWidth * 0.05),
                              _buildForm(screenWidth), // Main form section
                              // Member Picker (shown for appointments and habits)
                              if (_selectedType == TaskType.appointment ||
                                  _selectedType == TaskType.habit) ...[
                                SizedBox(height: screenWidth * 0.05),
                                _buildMemberPicker(screenWidth),
                              ],
                            ],
                          ),
                          // --- End Top Content ---

                          // --- Bottom Button Column ---
                          Padding(
                            padding: EdgeInsets.only(
                              top: screenWidth * 0.08, // Space above button
                              bottom: screenWidth * 0.1, // Bottom padding
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator()
                                : CustomButton(
                                    text: widget.isEditing
                                        ? 'อัปเดตงาน'
                                        : 'บันทึกงาน',
                                    isEnabled: true,
                                    onPressed: _saveTask,
                                  ),
                          ),
                          // --- End Bottom Button ---
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            // --- END UPDATE ---
          ],
        ),
      ),
    );
  }

  // Builds the main form content based on selected type
  Widget _buildForm(double screenWidth) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Common Fields
          _buildTextField(
            label: 'ชื่อ *',
            controller: _titleController,
            hint: _getHintText(),
            screenWidth: screenWidth,
          ),
          const SizedBox(height: 20),
          _buildTextField(
            label: 'คำอธิบาย (ไม่บังคับ)',
            controller: _descriptionController,
            hint: 'รายละเอียดเพิ่มเติม...',
            screenWidth: screenWidth,
            maxLines: 3,
          ),
          const SizedBox(height: 20),

          // --- Type-Specific Fields ---
          if (_selectedType == TaskType.appointment) ...[
            // --- USE WRAP FOR DATE/TIME PICKERS ---
            Wrap(
              spacing: 16.0, // Horizontal space between items
              runSpacing: 16.0, // Vertical space if items wrap
              alignment: WrapAlignment.center, // Center the items
              children: [
                // Date Picker (Constrained width)
                SizedBox(
                  // Calculate width.
                  // 24*2=48 (Container padding)
                  // 16 (Wrap spacing)
                  // 0.8 (Screen padding)
                  // Divide by 2
                  width:
                      (screenWidth * 0.8 - 48 - 16) /
                      2.1, // Use 2.1 or 2.2 for safety
                  child: _buildDateTimePicker(
                    label: 'วันที่',
                    text: _selectedDate == null
                        ? 'เลือกวันที่'
                        // Use consistent format
                        : DateFormat('dd/MM/yyyy', 'th').format(_selectedDate!),
                    onTap: _pickDate,
                    screenWidth: screenWidth,
                  ),
                ),
                // Time Picker (Constrained width)
                SizedBox(
                  width:
                      (screenWidth * 0.8 - 48 - 16) /
                      2.1, // Use 2.1 or 2.2 for safety
                  child: _buildDateTimePicker(
                    label: 'เวลา',
                    text: _selectedTime == null
                        ? 'เลือกเวลา'
                        : _selectedTime!.format(
                            context,
                          ), // Use context for locale format
                    onTap: _pickTime,
                    screenWidth: screenWidth,
                  ),
                ),
              ],
            ),
            // --- END WRAP ---
          ] else if (_selectedType == TaskType.countdown) ...[
            // Countdown only needs Date
            _buildDateTimePicker(
              label: 'วันที่เป้าหมาย',
              text: _selectedDate == null
                  ? 'เลือกวันที่'
                  // Use consistent format
                  : DateFormat('dd/MM/yyyy', 'th').format(_selectedDate!),
              onTap: _pickDate,
              screenWidth: screenWidth,
            ),
          ] else if (_selectedType == TaskType.habit) ...[
            // Habit has the Edit Schedule Button
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_calendar),
                label: const Text(
                  'แก้ไขตารางเวลาประจำสัปดาห์',
                  style: TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                ),
                onPressed: _editSchedule,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            // Show summary
            if (_habitSchedule.isNotEmpty &&
                _habitSchedule.values.any((list) => list.isNotEmpty)) ...[
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'กำหนดเวลาแล้ว ${_habitSchedule.values.fold(0, (prev, list) => prev + list.length)} รายการ',
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    color: Colors.green[700],
                  ),
                ),
              ),
            ] else if (_habitSchedule.isNotEmpty) ...[
              // Show if schedule exists but is empty
              const SizedBox(height: 10),
              const Center(
                child: Text(
                  'ยังไม่ได้กำหนดตารางเวลา',
                  style: TextStyle(
                    fontFamily: 'NotoLoopedThaiUI',
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // Gets hint text based on selected type
  String _getHintText() {
    switch (_selectedType) {
      case TaskType.appointment:
        return 'เช่น "นัดหมายหมอฟัน"';
      case TaskType.countdown:
        return 'เช่น "วันเกิดคุณยาย"';
      case TaskType.habit:
        return 'เช่น "กิจวัตรช่วงเช้า"';
      default:
        return 'ชื่องาน';
    }
  }

  // Reusable text field
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required double screenWidth,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              color: Colors.grey[400],
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[400]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2E88F3), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  // Reusable date/time picker button
  Widget _buildDateTimePicker({
    required String label,
    required String text,
    required VoidCallback onTap,
    required double screenWidth,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'NotoLoopedThaiUI',
            fontSize: screenWidth * 0.04,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[400]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8), // Add a small gap
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Care Receiver selection list
  Widget _buildMemberPicker(double screenWidth) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'มอบหมายให้ *',
            style: TextStyle(
              fontFamily: 'NotoLoopedThaiUI',
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          if (_isLoadingMembers)
            const Center(child: CircularProgressIndicator())
          else if (_careReceivers.isEmpty)
            const Center(
              child: Text(
                'ไม่มีผู้รับการดูแลในกลุ่มนี้',
                style: TextStyle(
                  fontFamily: 'NotoLoopedThaiUI',
                  color: Colors.grey,
                ),
              ),
            )
          else
            Column(
              children: _careReceivers.map((receiver) {
                final uid = receiver['uid'];
                final username = receiver['username'];
                return CheckboxListTile(
                  title: Text(
                    username,
                    style: const TextStyle(fontFamily: 'NotoLoopedThaiUI'),
                  ),
                  value: _selectedReceivers[uid] ?? false,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedReceivers[uid] = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: const Color(0xFF2E88F3),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
