import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../services/db/sqlite_service.dart';
import '../../dashboard/services/dashboard_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/repositories/auth_repository.dart';

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
  final int pendingAdmissions;

  DashboardMetrics({
    required this.attendancePercentage,
    required this.totalStudents,
    required this.pendingFees,
    required this.pendingAdmissions,
  });
}

class DashboardRepository {
  final DashboardService _service;

  DashboardRepository(SQLiteService db) : _service = DashboardService(db);

  /// Combines SQL raw queries into a unified metrics object mapping.
  Future<DashboardMetrics> fetchMetrics() async {
    if (kIsWeb) {
      final webMetrics = await _fetchMetricsFromApi();
      if (webMetrics != null) return webMetrics;
    }

    try {
      final attendance = await _service.getTodayAttendancePercentage();
      final students = await _service.getTotalStudents();
      final fees = await _service.getPendingFees();
      final pendingAdmissions = await _service.getPendingAdmissions();

      if (students > 0 || fees > 0 || pendingAdmissions > 0) {
        return DashboardMetrics(
          attendancePercentage: attendance,
          totalStudents: students,
          pendingFees: fees,
          pendingAdmissions: pendingAdmissions,
        );
      }
    } catch (e) {
      debugPrint("SQLite metrics error: $e");
    }

    // Direct HTTP API Fallback
    final fallbackMetrics = await _fetchMetricsFromApi();
    if (fallbackMetrics != null) return fallbackMetrics;

    return DashboardMetrics(
      attendancePercentage: 0.0,
      totalStudents: 0,
      pendingFees: 0.0,
      pendingAdmissions: 0,
    );
  }

  Future<DashboardMetrics?> _fetchMetricsFromApi() async {
    try {
      final session = await AuthRepository().getSession();
      if (session == null) return null;
      final response = await http.get(
        Uri.parse('$BASE_URL/admin/metrics'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final d = json['data'];
        return DashboardMetrics(
          attendancePercentage: (d['attendancePercentage'] as num?)?.toDouble() ?? 0.0,
          totalStudents: (d['totalStudents'] as num?)?.toInt() ?? 0,
          pendingFees: (d['pendingFees'] as num?)?.toDouble() ?? 0.0,
          pendingAdmissions: (d['pendingAdmissions'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (e) {
      debugPrint("API metrics fetch error: $e");
    }
    return null;
  }
}
