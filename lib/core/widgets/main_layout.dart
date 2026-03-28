import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/dashboard/screens/teacher_dashboard.dart';
import '../../features/dashboard/screens/parent_dashboard.dart';
import '../../features/dashboard/screens/accountant_dashboard.dart';
import '../../features/students/screens/students_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/fees/screens/fees_screen.dart';
import '../../features/sync/screens/conflict_logs_screen.dart';
import '../../features/backup/screens/backup_screen.dart';
import '../../features/timetable/screens/timetable_screen.dart';
import '../../features/marks/screens/marks_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import 'sync_status_badge.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(userRoleProvider);

    final List<Widget> screens;
    final List<BottomNavigationBarItem> navItems;

    switch (role) {
      case UserRole.admin:
        screens = [
          const AdminDashboard(),
          const StudentsScreen(),
          const AttendanceScreen(),
          const FeesScreen(),
          const ConflictLogsScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.people_rounded), label: 'Students'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Fees'),
          BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_rounded), label: 'Audit'),
        ];
        break;

      case UserRole.teacher:
        screens = [
          const TeacherDashboard(),
          const AttendanceScreen(),
          const MarksScreen(),
          const TimetableScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.fact_check_rounded), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.grading_rounded), label: 'Marks'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule_rounded), label: 'Timetable'),
        ];
        break;

      case UserRole.parent:
        screens = [
          const ParentDashboard(),
          const FeesScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Fees'),
        ];
        break;

      case UserRole.student:
        screens = [
          const ParentDashboard(),
          const FeesScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Fees'),
        ];
        break;

      case UserRole.accountant:
        screens = [
          const AccountantDashboard(),
          const FeesScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.payments_rounded), label: 'Fees'),
        ];
        break;
    }

    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    // Role badge color
    Color roleBadgeColor;
    switch (role) {
      case UserRole.admin:
        roleBadgeColor = Colors.red;
        break;
      case UserRole.teacher:
        roleBadgeColor = Colors.blue;
        break;
      case UserRole.accountant:
        roleBadgeColor = Colors.teal;
        break;
      case UserRole.parent:
        roleBadgeColor = Colors.green;
        break;
      case UserRole.student:
        roleBadgeColor = Colors.purple;
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            // App name
            const Text(
              'KVM ERP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleBadgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                role.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: roleBadgeColor,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          const SyncStatusBadge(),
          // Profile / Logout menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 16,
              backgroundColor: roleBadgeColor.withOpacity(0.15),
              child: Icon(Icons.person_rounded, size: 18, color: roleBadgeColor),
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            offset: const Offset(0, 45),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${role.name[0].toUpperCase()}${role.name.substring(1)} Account',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      'Logged in as ${role.name}@kvm.edu',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red[400])),
                  ],
                ),
              ),
            ],
            onSelected: (value) async {
              if (value == 'logout') {
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
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: navItems.length > 1
          ? Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) => setState(() => _currentIndex = index),
                items: navItems,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: roleBadgeColor,
                unselectedItemColor: Colors.grey[400],
                selectedFontSize: 12,
                unselectedFontSize: 11,
                elevation: 8,
              ),
            )
          : null,
    );
  }
}
