import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/student_model.dart';
import '../../../../services/db/sqlite_service.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepository(SQLiteService());
});

class StudentRepository {
  final SQLiteService _dbService;
  
  // IN-MEMORY CACHING
  // This prevents frequent DB IO hits when scrolling through student lists
  List<StudentModel>? _cachedStudents;

  StudentRepository(this._dbService);

  /// Fetch all active students (ignores soft-deleted) with Lazy Loading / Pagination Support
  Future<List<StudentModel>> getAllStudents({
    bool forceRefresh = false, 
    int limit = 20, 
    int offset = 0
  }) async {
    // Return cache immediately if valid AND we are requesting the initial chunk basically
    if (!forceRefresh && _cachedStudents != null && offset == 0 && _cachedStudents!.length >= limit) {
      return _cachedStudents!.take(limit).toList();
    }

    final db = await _dbService.database;
    final results = await db.query(
      'students', 
      where: 'is_deleted = ?', 
      whereArgs: [0],
      limit: limit,
      offset: offset,
      orderBy: 'name ASC', // Optional logical sort
    );
    
    final fetched = results.map((e) => StudentModel.fromJson(e)).toList();
    
    if (offset == 0) {
      _cachedStudents = fetched; // overwrite baseline cache
    } else if (_cachedStudents != null) {
      _cachedStudents!.addAll(fetched); // incrementally append
    }
    
    return fetched;
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
        'data': data.toString(), 
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'attempt_count': 0,
      });
  }
}

