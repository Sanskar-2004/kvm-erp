import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../attendance/screens/attendance_screen.dart';
import '../../marks/screens/marks_screen.dart';
import '../../timetable/screens/timetable_screen.dart';
import '../../students/screens/students_screen.dart';
import '../../notices/screens/notices_screen.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../services/db/sqlite_service.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  String _teacherName = 'Teacher';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  Future<void> _loadName() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;
    try {
      final db = SQLiteService();
      final res = await db.query('staff', where: 'user_id = ? OR id = ?', whereArgs: [session.userId, session.userId], limit: 1);
      if (res.isNotEmpty && mounted) {
        setState(() => _teacherName = res.first['name'].toString().split(' ').first); // Use first name
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 900 ? 3 : (width > 600 ? 3 : 2);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Teacher Header Banner ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Good Morning, $_teacherName!',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Here\'s your day at a glance',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
                // Explicit Header Logout Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red[600],
                    side: BorderSide(color: Colors.red.shade200),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Logout', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Confirm Logout'),
                        content: const Text('Are you sure you want to log out of KVM ERP?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Logout', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Today's Quick Actions ──
            GridView.count(
              crossAxisCount: crossAxisCount,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: width > 600 ? 1.5 : 1.1,
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
                _TeacherAction(
                  title: 'Send Notice',
                  subtitle: 'Alert students & parents',
                  icon: Icons.campaign_rounded,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NoticesScreen(canCreate: true))),
                ),
                _TeacherAction(
                  title: 'View Notices',
                  subtitle: 'See alerts from admin',
                  icon: Icons.notifications_rounded,
                  color: Colors.orange,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NoticesScreen(canCreate: false))),
                ),
              ],
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
