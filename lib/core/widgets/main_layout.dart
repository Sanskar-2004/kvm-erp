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
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
        ];
        break;

      case UserRole.student:
        screens = [
          const ParentDashboard(), // Students see similar read-only view
        ];
        navItems = const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
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

    // Clamp index if role changes and has fewer tabs
    if (_currentIndex >= screens.length) {
      _currentIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('KVM ERP • ${role.name.toUpperCase()}'),
        centerTitle: false,
        actions: const [SyncStatusBadge()],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: navItems.length > 1
          ? BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              items: navItems,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Theme.of(context).colorScheme.primary,
            )
          : null,
    );
  }
}
