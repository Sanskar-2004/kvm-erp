import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
import '../../students/screens/students_screen.dart';
import '../../fees/screens/fees_screen.dart';
import '../../timetable/screens/timetable_manager_screen.dart';
import '../../backup/screens/backup_screen.dart';
import '../../admission/screens/admission_screen.dart';
import '../../staff/screens/staff_screen.dart';
import '../../staff/screens/assign_staff_screen.dart';
import 'admin_finance_screen.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin Overview',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // ── Stats Grid ──
            metricsAsync.when(
              data: (metrics) => GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: [
                  _StatCard(
                      title: 'Total Students',
                      value: '${metrics.totalStudents}',
                      icon: Icons.school_rounded,
                      color: Colors.blue),
                  _StatCard(
                      title: 'Pending Fees',
                      value: '₹${metrics.pendingFees.toStringAsFixed(0)}',
                      icon: Icons.money_off_rounded,
                      color: Colors.red),
                  _StatCard(
                      title: 'Attendance',
                      value: '${metrics.attendancePercentage.toStringAsFixed(1)}%',
                      icon: Icons.check_circle_rounded,
                      color: Colors.green),
                  _StatCard(
                      title: 'Admissions',
                      value: 'Pending',
                      icon: Icons.person_add_rounded,
                      color: Colors.orange),
                ],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),

            // ── Quick Actions ──
            Text('Quick Actions',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _ActionCard(
                    title: 'Manage Students',
                    icon: Icons.people_rounded,
                    color: Colors.blue,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const StudentsScreen()))),
                _ActionCard(
                    title: 'Manage Staff',
                    icon: Icons.badge_rounded,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const StaffScreen()))),
                _ActionCard(
                    title: 'Assign Staff',
                    icon: Icons.assignment_ind_rounded,
                    color: Colors.deepOrange,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AssignStaffScreen()))),
                _ActionCard(
                    title: 'Manage Fees',
                    icon: Icons.payment_rounded,
                    color: Colors.green,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const FeesScreen()))),
                _ActionCard(
                    title: 'Timetable',
                    icon: Icons.schedule_rounded,
                    color: Colors.purple,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TimetableManagerScreen()))),
                _ActionCard(
                    title: 'Backup',
                    icon: Icons.backup_rounded,
                    color: Colors.teal,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const BackupScreen()))),
                _ActionCard(
                    title: 'Admissions',
                    icon: Icons.how_to_reg_rounded,
                    color: Colors.orange,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdmissionScreen()))),
                _ActionCard(
                    title: 'Finance',
                    icon: Icons.analytics_rounded,
                    color: Colors.indigo,
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminFinanceScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Card Widget ──
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(title,
              style: TextStyle(color: Colors.grey[700], fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ── Quick Action Card Widget ──
class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
