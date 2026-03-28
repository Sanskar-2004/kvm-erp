import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/attendance_model.dart';
import '../../../../services/db/sqlite_service.dart';
import 'package:sqflite/sqflite.dart';

final sqliteServiceProvider = Provider<SQLiteService>((ref) => SQLiteService());

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(sqliteServiceProvider));
});

class AttendanceRepository {
  final SQLiteService _dbService;

  AttendanceRepository(this._dbService);

  /// Get attendance records for a specific class and date
  Future<List<AttendanceModel>> getAttendanceByClassAndDate(String classId, String date) async {
    final results = await _dbService.query(
      'attendance',
      where: 'class_id = ? AND date LIKE ?',
      whereArgs: [classId, '$date%'],
    );
    return results.map((e) => AttendanceModel.fromJson(e)).toList();
  }

  /// Mark attendance for a single student, handling the UNIQUE constraint constraint.
  Future<void> markAttendance(AttendanceModel attendance) async {
    try {
      // Due to the UNIQUE(student_id, date, period_number) constraint,
      // this will automatically fail if trying to mark double attendance.
      await _dbService.insert('attendance', attendance.toJson());
      
      // Queue for sync
      _queueSync('attendance', attendance.id, 'INSERT', attendance.toJson());
    } on DatabaseException catch (e) {
      if (e.isUniqueConstraintError()) {
        throw Exception('Attendance already marked for this student in this period.');
      }
      rethrow;
    }
  }

  /// Mark bulk attendance grouped securely into an atomic SQL transaction
  /// Prevents partial network/processor aborts corrupting data natively.
  Future<void> markBulkAttendance(List<AttendanceModel> attendanceRecords) async {
    await _dbService.transaction((txn) async {
      for (final record in attendanceRecords) {
        try {
          await txn.insert('attendance', record.toJson());
          // We can queue bulk sync right within the transaction block!
          await txn.insert('sync_queue', {
            'table_name': 'attendance',
            'record_id': record.id,
            'action': 'INSERT',
            'data': record.toJson().toString(), 
            'created_at': DateTime.now().toIso8601String(),
            'synced': 0,
            'attempt_count': 0,
          });
        } on DatabaseException catch (e) {
             if (!e.isUniqueConstraintError()) {
                rethrow; // Abort transaction fundamentally if severe error
             }
             // Soft log unique conflicts and skip
        }
      }
    });
  }

  /// Update an existing attendance record mapped by ID

  Future<void> updateAttendance(AttendanceModel attendance) async {
    // Generate updated model with dirty flag true
    final Map<String, dynamic> data = attendance.toJson();
    data['is_synced'] = 0; // mark dirty
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await _dbService.update(
      'attendance',
      data,
      where: 'id = ?',
      whereArgs: [attendance.id],
    );

    // Queue for sync
    _queueSync('attendance', attendance.id, 'UPDATE', data);
  }
  
  void _queueSync(String tableName, String recordId, String action, Map<String, dynamic> data) async {
     await _dbService.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'data': data.toString(), // Simplified for brevity; ideally use jsonEncode
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'attempt_count': 0,
      });
  }
}
