import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/staff_assignment_model.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';
import '../../attendance/repositories/attendance_repository.dart';

final assignmentRepositoryProvider = Provider((ref) => AssignmentRepository(
      ref.read(sqliteServiceProvider), // Provided in auth or attendance module
      ref,
    ));

class AssignmentRepository {
  final SQLiteService _sqliteService;
  final Ref _ref;

  AssignmentRepository(this._sqliteService, this._ref);

  Future<List<StaffAssignmentModel>> getAssignmentsByClass(String classId) async {
    // 1st Priority: Database Pull for online/offline fluidity
    // But since join is required, we use rawQuery or hit API
    
    final session = await _ref.read(authRepositoryProvider).getSession();
    if (session == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/assignments?class_id=$classId'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['assignments'] as List).map((x) => StaffAssignmentModel.fromMap(x)).toList();
      }
    } catch (e) {
       // fallback offline
    }
    
    return [];
  }
  
  Future<List<StaffAssignmentModel>> getAssignmentsByStaff(String staffId) async {
    final session = await _ref.read(authRepositoryProvider).getSession();
    if (session == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/assignments?staff_id=$staffId'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['assignments'] as List).map((x) => StaffAssignmentModel.fromMap(x)).toList();
      }
    } catch (e) {
       // fallback offline
    }
    return [];
  }

  Future<void> createAssignment(StaffAssignmentModel assignment) async {
    final session = await _ref.read(authRepositoryProvider).getSession();
    if (session == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$BASE_URL/assignments'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode(assignment.toMap()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to create assignment');
    }
  }

  Future<void> deleteAssignment(String id) async {
    final session = await _ref.read(authRepositoryProvider).getSession();
    if (session == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$BASE_URL/assignments/$id'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete assignment');
    }
  }
}
