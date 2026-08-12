import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/screens/admin_dashboard.dart';
import '../../features/dashboard/screens/teacher_dashboard.dart';
import '../../features/dashboard/screens/parent_dashboard.dart';
import '../../features/dashboard/screens/student_dashboard.dart';
import '../../features/dashboard/screens/accountant_dashboard.dart';
import '../../features/students/screens/students_screen.dart';
import '../../features/attendance/screens/attendance_screen.dart';
import '../../features/fees/screens/fees_screen.dart';
import '../../features/fees/screens/student_fee_screen.dart';
import '../../features/fees/screens/parent_fee_screen.dart';
import '../../features/sync/screens/conflict_logs_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../services/sync/sync_service.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import 'sync_status_badge.dart';

class MainLayout extends ConsumerStatefulWidget {
  const MainLayout({Key? key}) : super(key: key);

  @override
  ConsumerState<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends ConsumerState<MainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(syncServiceProvider).runSyncSafe();
        if (mounted) {
          ref.invalidate(studentsListProvider);
          ref.invalidate(dashboardMetricsProvider);
        }
      } catch (e) {
        debugPrint("MainLayout initial sync warning: $e");
      }
    });
  }

  Future<void> _performLogout(BuildContext context) async {
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
  }

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
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded), label: 'Students'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_rounded), label: 'Attendance'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments_rounded), label: 'Fees'),
          BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings_rounded), label: 'Audit'),
        ];
        break;

      case UserRole.teacher:
        screens = [
          const TeacherDashboard(),
          const StudentsScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_rounded), label: 'Students'),
        ];
        break;

      case UserRole.parent:
        screens = [
          const ParentDashboard(),
          const ParentFeeScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments_rounded), label: 'Fees'),
        ];
        break;

      case UserRole.student:
        screens = [
          const StudentDashboard(),
          const StudentFeeScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments_rounded), label: 'Fees'),
        ];
        break;

      case UserRole.accountant:
        screens = [
          const AccountantDashboard(),
          const FeesScreen(),
        ];
        navItems = const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments_rounded), label: 'Fees'),
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

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.15), width: 1)),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App name
            const Text(
              'KVM ERP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
            ),
            const SizedBox(width: 6),
            // Role badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleBadgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                role.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: roleBadgeColor,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        centerTitle: false,
        elevation: 0,
        actions: [
          const SyncStatusBadge(),
          const SizedBox(width: 4),
          // Explicit Logout Button (icon-only on mobile, full button on desktop)
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 20),
              tooltip: 'Logout',
              onPressed: () => _performLogout(context),
            )
          else
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[600],
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: Colors.red.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 16),
              label: const Text(
                'Logout',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _performLogout(context),
            ),
          const SizedBox(width: 4),
          // Profile avatar menu
          PopupMenuButton<String>(
            icon: CircleAvatar(
              radius: 15,
              backgroundColor: roleBadgeColor.withOpacity(0.15),
              child: Icon(Icons.person_rounded, size: 16, color: roleBadgeColor),
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
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    Text(
                      'Logged in as ${role.name}',
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
                    Icon(Icons.logout_rounded,
                        size: 18, color: Colors.red[400]),
                    const SizedBox(width: 8),
                    Text('Logout', style: TextStyle(color: Colors.red[400])),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _performLogout(context);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: screens[_currentIndex],
        ),
      ),
      bottomNavigationBar: navItems.length > 1
          ? Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Container(
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
                ),
              ),
            )
          : null,
    );
  }
}
