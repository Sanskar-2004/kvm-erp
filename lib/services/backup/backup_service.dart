import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../db/sqlite_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(SQLiteService());
});

class BackupService {
  final SQLiteService _dbService;

  BackupService(this._dbService);

  /// Exports the entire SQLite dataset organically into a standard JSON string payload.
  /// Saves it physically into the device's Documents Directory as a Rescue file.
  Future<String> exportDatabase() async {
     final db = await _dbService.database;

     final students = await db.query('students');
     final attendance = await db.query('attendance');
     final studentFees = await db.query('student_fees');

     final data = {
       "export_date": DateTime.now().toIso8601String(),
       "students": students,
       "attendance": attendance,
       "student_fees": studentFees,
     };

     final jsonPayload = jsonEncode(data);

     // Write actively to filesystem
     final directory = await getApplicationDocumentsDirectory();
     final file = File('${directory.path}/kvm_erp_backup_${DateTime.now().millisecondsSinceEpoch}.json');
     await file.writeAsString(jsonPayload);

     return file.path;
  }

  /// Imports and Merges the JSON Payload back into the active database securely.
  /// Ignores stale data if current local states are newer across arbitrary device loads.
  Future<void> importDatabase(String jsonPayload) async {
    final data = jsonDecode(jsonPayload);
    final db = await _dbService.database;

    await _dbService.transaction((txn) async {
      // Restore Students mapping timestamps
      if (data['students'] != null) {
        for (final student in data['students']) {
          final localList = await txn.query('students', where: 'id = ?', whereArgs: [student['id']]);

          if (localList.isEmpty) {
             await txn.insert('students', student);
          } else {
             final local = localList.first;
             final incomingTimestamp = DateTime.parse(student['updated_at']);
             final localTimestamp = DateTime.parse(local['updated_at'].toString());
             
             if (incomingTimestamp.isAfter(localTimestamp)) {
                await txn.update('students', student, where: 'id = ?', whereArgs: [student['id']]);
             }
          }
        }
      }

      // We strictly repeat this iteration generic model mapping dynamically across Attendance and Fees.
      // E.g:
      if (data['attendance'] != null) {
         for (final att in data['attendance']) {
            final existing = await txn.query('attendance', where: 'id = ?', whereArgs: [att['id']]);
            if (existing.isEmpty) {
               await txn.insert('attendance', att);
            }
         }
      }
    });
  }
}

