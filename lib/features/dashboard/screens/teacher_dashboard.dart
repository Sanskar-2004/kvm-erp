import 'package:flutter/material.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../../marks/screens/marks_screen.dart';
import '../../timetable/screens/timetable_screen.dart';
import '../../students/screens/students_screen.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Good Morning, Teacher!',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Here\'s your day at a glance',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),

            // ── Today's Quick Actions ──
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _TeacherAction(
                    title: 'Mark Attendance',
                    subtitle: 'Take today\'s roll call',
                    icon: Icons.fact_check_rounded,
                    color: Colors.green,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                  ),
                  _TeacherAction(
                    title: 'Enter Marks',
                    subtitle: 'Record exam results',
                    icon: Icons.grading_rounded,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const MarksScreen())),
                  ),
                  _TeacherAction(
                    title: 'My Timetable',
                    subtitle: 'View today\'s schedule',
                    icon: Icons.schedule_rounded,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TimetableScreen())),
                  ),
                  _TeacherAction(
                    title: 'Submit Admission',
                    subtitle: 'Register new student',
                    icon: Icons.person_add_alt_1_rounded,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const StudentsScreen()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TeacherAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 36),
            const Spacer(),
            Text(title,
                style: TextStyle(
                    color: color, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
