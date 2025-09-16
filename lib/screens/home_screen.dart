import 'package:flutter/material.dart';
import '../widgets/background_circles.dart';
import '../widgets/custom_bottom_navigation.dart';
import './groups_screen.dart';
import './settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 1; // home tab

  final Map<String, Color> dayColors = {
    'Monday': Colors.yellow,
    'Tuesday': Colors.pink,
    'Wednesday': Colors.green,
    'Thursday': Colors.orange,
    'Friday': Colors.blue,
    'Saturday': Colors.purple,
    'Sunday': Colors.red,
  };

  // Example groups with tasks
  final List<Map<String, dynamic>> groups = [
    {
      'name': 'สุขภาพดี',
      'description': 'กลุ่มสำหรับติดตามสุขภาพ',
      'tasks': [
        'ดื่มน้ำ 8 แก้ว',
        'ออกกำลังกาย 30 นาที',
        'ทานผักและผลไม้',
        'พักผ่อน 8 ชั่วโมง',
        'ทานยา',
        'ทำสมาธิ 10 นาที',
      ],
    },
    {
      'name': 'การเรียน',
      'description': 'กลุ่มสำหรับติดตามงานเรียน',
      'tasks': [
        'อ่านหนังสือ 1 ชั่วโมง',
        'ทำการบ้านวิชาคณิต',
        'ทบทวนบทเรียนภาษาอังกฤษ',
      ],
    },
  ];

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
      'Sunday'
    ][today.weekday - 1];

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Stack(
          children: [
            // Background circles
            Positioned(
              bottom: -screenWidth * 0.5,
              left: -screenWidth * 0.25,
              child: const BottomBackgroundCircles(),
            ),

            // Main content
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  _buildHeader(screenWidth),
                  SizedBox(height: screenHeight * 0.02),
                  _buildTodayLabel(weekdayName, screenWidth),
                  SizedBox(height: screenHeight * 0.03),

                  // Scrollable groups list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 120),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        return _buildGroupCard(groups[index], screenWidth);
                      },
                    ),
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
              'ผู้ใช้งาน',
              style: TextStyle(
                fontFamily: 'NotoLoopedThaiUI',
                fontSize: screenWidth * 0.08,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2E88F3),
              ),
            ),
          ],
        ),
        // Avatar
        Container(
          width: screenWidth * 0.12,
          height: screenWidth * 0.12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFD1D5DB),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.person,
            size: screenWidth * 0.06,
            color: const Color(0xFF9CA3AF),
          ),
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
        color: dayColors[weekdayName],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group, double screenWidth) {
    final List<String> tasks = List<String>.from(group['tasks']);
    bool expanded = false;
    final List<bool> checked = List<bool>.filled(tasks.length, false);

    return StatefulBuilder(
      builder: (context, setInnerState) {
        final visibleTasks = expanded ? tasks : tasks.take(5).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group header
              Row(
                children: [
                  _buildGroupImage(group['image']),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group['name'],
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.05,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E88F3),
                          ),
                        ),
                        Text(
                          group['description'],
                          style: TextStyle(
                            fontFamily: 'NotoLoopedThaiUI',
                            fontSize: screenWidth * 0.038,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Tasks
              ...visibleTasks.map((task) {
                final index = tasks.indexOf(task);
                return CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  value: checked[index],
                  onChanged: (value) {
                    setInnerState(() {
                      checked[index] = value ?? false;
                    });
                  },
                  title: Text(
                    task,
                    style: TextStyle(
                      fontFamily: 'NotoLoopedThaiUI',
                      fontSize: screenWidth * 0.038,
                      decoration: checked[index]
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: checked[index] ? Colors.grey : Colors.black,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),

              if (tasks.length > 5)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFF9CA3AF),
                    ),
                    onPressed: () {
                      setInnerState(() => expanded = !expanded);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGroupImage(String? imagePath) {
    if (imagePath != null && imagePath.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _fallbackGroupIcon();
          },
        ),
      );
    } else {
      return _fallbackGroupIcon();
    }
  }

  Widget _fallbackGroupIcon() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.group,
        color: Colors.blue,
        size: 24,
      ),
    );
  }
}
