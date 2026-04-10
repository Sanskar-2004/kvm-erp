import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/db/sqlite_service.dart';

class DashboardService {
  final SQLiteService _db;

  DashboardService(this._db);

  /// Retrieves the attendance percentage for the current day across the school.
  Future<double> getTodayAttendancePercentage() async {
    final now = DateTime.now();
    final todayStr = DateTime(now.year, now.month, now.day).toIso8601String().split('T')[0];

    // Ideally, we sum up all presences for the day vs total students enrolled
    // Doing this in SQL via rawQuery for max efficiency:
    final db = await _db.database;
    final res = await db.rawQuery('''
      SELECT 
        COUNT(CASE WHEN status = 'present' THEN 1 END) as present_count,
        COUNT(id) as total_attendance
      FROM attendance
      WHERE date LIKE ?
    ''', ['$todayStr%']);

    if (res.isEmpty) return 0.0;
    
    final int present = SqfliteUtils.toInt(res.first['present_count']) ?? 0;
    final int total = SqfliteUtils.toInt(res.first['total_attendance']) ?? 0;

    if (total == 0) return 0.0;
    return (present / total) * 100;
  }

  /// Retrieves the total number of students in the school
  Future<int> getTotalStudents() async {
    final db = await _db.database;
    final res = await db.rawQuery('SELECT COUNT(id) as count FROM students WHERE is_deleted = 0');
    
    if (res.isEmpty) return 0;
    return SqfliteUtils.toInt(res.first['count']) ?? 0;
  }

  /// Retrieves the total pending (due) fees from the student_fees table
  Future<double> getPendingFees() async {
    final db = await _db.database;
    final res = await db.rawQuery(
      'SELECT SUM(amount_due - amount_paid) as total_due FROM student_fees WHERE status != ?',
      ['PAID'],
    );

    if (res.isEmpty || res.first['total_due'] == null) return 0.0;
    return (res.first['total_due'] as num).toDouble();
  }
}

// Ensure safe type parsing for sqflite results
class SqfliteUtils {
  static int? toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// Future providers for accessing dashboard stats easily via Riverpod:
// Depends on a sqliteServiceProvider which we'll implement later
// For now, this exposes the DashboardService instance:
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  // Return an instance wrapped over our singleton SQLite service instance:
  return DashboardService(SQLiteService());
});
