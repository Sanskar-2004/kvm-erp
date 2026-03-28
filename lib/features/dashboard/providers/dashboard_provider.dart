import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardStats {
  final int totalStudents;
  final double attendancePercentage;
  final String feesCollected;
  final int activeNotices;

  const DashboardStats({
    this.totalStudents = 0,
    this.attendancePercentage = 0,
    this.feesCollected = '0',
    this.activeNotices = 0,
  });
}

// Mock provider — replace with real data fetching
final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  return const DashboardStats(
    totalStudents: 1250,
    attendancePercentage: 92.5,
    feesCollected: '12.5L',
    activeNotices: 5,
  );
});
