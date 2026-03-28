import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../dashboard/services/dashboard_service.dart';

// Provides the repository bridging DB and Providers.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(SQLiteService());
});

// Provides realtime reactive state for the Dashboard UI
// This forces complete UI recompilation whenever invalidate is called throughout the app.
final dashboardMetricsProvider = FutureProvider.autoDispose<DashboardMetrics>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return await repo.fetchMetrics();
});

class DashboardMetrics {
  final double attendancePercentage;
  final int totalStudents;
  final double pendingFees;

  DashboardMetrics({
    required this.attendancePercentage,
    required this.totalStudents,
    required this.pendingFees,
  });
}

class DashboardRepository {
  final DashboardService _service;

  DashboardRepository(SQLiteService db) : _service = DashboardService(db);

  /// Combines SQL raw queries into a unified metrics object mapping.
  Future<DashboardMetrics> fetchMetrics() async {
    final attendance = await _service.getTodayAttendancePercentage();
    final students = await _service.getTotalStudents();
    final fees = await _service.getPendingFees();

    return DashboardMetrics(
      attendancePercentage: attendance,
      totalStudents: students,
      pendingFees: fees,
    );
  }
}
