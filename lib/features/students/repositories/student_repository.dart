import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../models/student_model.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../auth/repositories/auth_repository.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(SQLiteService());
});

class StudentRepository {
  final SQLiteService _dbService;
  
  // IN-MEMORY CACHING
  List<StudentModel>? _cachedStudents;

  StudentRepository(this._dbService);

  /// Fetch all active students (ignores soft-deleted) with Lazy Loading / Pagination Support
  Future<List<StudentModel>> getAllStudents({
    bool forceRefresh = false, 
    int limit = 500, 
    int offset = 0
  }) async {
    if (!forceRefresh && _cachedStudents != null && offset == 0 && _cachedStudents!.isNotEmpty) {
      return _cachedStudents!;
    }

    if (kIsWeb) {
      final webFetched = await _fetchStudentsFromApi();
      if (webFetched != null && webFetched.isNotEmpty) {
        _cachedStudents = webFetched;
        return webFetched;
      }
    }

    try {
      final db = await _dbService.database;
      final results = await db.query(
        'students', 
        where: 'is_deleted = ? OR is_deleted IS NULL', 
        whereArgs: [0],
        limit: limit,
        offset: offset,
        orderBy: 'name ASC',
      );
      
      final fetched = results.map((e) => StudentModel.fromJson(e)).toList();
      
      if (fetched.isNotEmpty) {
        if (offset == 0) _cachedStudents = fetched;
        return fetched;
      }
    } catch (e) {
      debugPrint("SQLite query error: $e");
    }

    // Direct HTTP API Fallback
    final fallbackFetched = await _fetchStudentsFromApi();
    if (fallbackFetched != null) {
      _cachedStudents = fallbackFetched;
      return fallbackFetched;
    }

    return _cachedStudents ?? [];
  }

  Future<List<StudentModel>?> _fetchStudentsFromApi() async {
    try {
      final session = await AuthRepository().getSession();
      if (session == null) return null;
      final response = await http.get(
        Uri.parse('$BASE_URL/students'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List list = data['students'] ?? [];
        return list.map((e) => StudentModel.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      debugPrint("API students fetch error: $e");
    }
    return null;
  }

  /// Exposed manual trigger to clear cache natively after heavy Bulk Sync Pulls
  void invalidateStudentCache() {
    _cachedStudents = null;
  }

  Future<void> addStudent(StudentModel student) async {
    await _dbService.insert('students', student.toJson());
    // Invalidate instead of blindly pushing, keeping sync robust 
    invalidateStudentCache(); 
    _queueSync('students', student.id, 'INSERT', student.toJson());
  }

  /// Update an existing student's data.
  Future<void> updateStudent(StudentModel student) async {
    final updated = student.copyWith(
      updatedAt: DateTime.now(),
      isSynced: false,
    );

    await _dbService.update(
      'students',
      updated.toJson(),
      where: 'id = ?',
      whereArgs: [updated.id],
    );

    invalidateStudentCache();
    _queueSync('students', updated.id, 'UPDATE', updated.toJson());
  }

  /// Soft Delete Implementation
  Future<void> deleteStudentSoft(String studentId) async {
    final updateData = {
      'is_deleted': 1,
      'is_synced': 0, // mark dirty
      'updated_at': DateTime.now().toIso8601String(),
    };

    await _dbService.update(
      'students', 
      updateData, 
      where: 'id = ?', 
      whereArgs: [studentId]
    );

    // Cascade: also soft-delete all fee records for this student
    await _dbService.update(
      'student_fees',
      {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
      where: 'student_id = ?',
      whereArgs: [studentId],
    );

    // Remove from in-memory cache instantly for UI responsiveness
    _cachedStudents?.removeWhere((s) => s.id == studentId);
    
    // Sync to let server know we soft deleted
    _queueSync('students', studentId, 'UPDATE', updateData);
  }

  void _queueSync(String tableName, String recordId, String action, Map<String, dynamic> data) async {
      await _dbService.insert('sync_queue', {
        'table_name': tableName,
        'record_id': recordId,
        'action': action,
        'data': jsonEncode(data), 
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'attempt_count': 0,
      });
  }

  /// Bulk insert students using a batch transaction for performance.
  /// Returns the number of students successfully inserted.
  Future<int> bulkAddStudents(List<StudentModel> students) async {
    if (students.isEmpty) return 0;

    final db = await _dbService.database;

    // Batch insert inside a transaction for speed
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final student in students) {
        batch.insert(
          'students',
          student.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });

    // Queue each for sync (outside transaction so stream notifications fire)
    for (final student in students) {
      _queueSync('students', student.id, 'INSERT', student.toJson());
    }

    invalidateStudentCache();
    return students.length;
  }
}
