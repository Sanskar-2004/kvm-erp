import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/staff_model.dart';
import '../../../services/db/sqlite_service.dart';
import '../../attendance/repositories/attendance_repository.dart';
import '../../../core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';

final staffRepositoryProvider = Provider((ref) => StaffRepository(
      ref.read(sqliteServiceProvider),
      ref,
    ));

class StaffRepository {
  final SQLiteService _sqliteService;
  final Ref _ref;

  StaffRepository(this._sqliteService, this._ref);

  Future<List<StaffModel>> getAllStaff() async {
    final result = await _sqliteService.query(
      'staff',
      where: 'is_deleted = 0',
      orderBy: 'name ASC',
    );
    return result.map((e) => StaffModel.fromMap(e)).toList();
  }

  Future<List<StaffModel>> getStaffByRole(String role) async {
    final result = await _sqliteService.query(
      'staff',
      where: 'is_deleted = 0 AND role = ?',
      whereArgs: [role],
      orderBy: 'name ASC',
    );
    return result.map((e) => StaffModel.fromMap(e)).toList();
  }

  Future<void> createStaffWithAuth(StaffModel staff, {String? username, String? password}) async {
    final session = await _ref.read(authRepositoryProvider).getSession();
    if (session == null) throw Exception('Not authenticated');

    // Online-only explicit creation for Auth payload combinations
    final response = await http.post(
      Uri.parse('$BASE_URL/staff'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        ...staff.toMap(),
        if (staff.canLogin) 'username': username,
        if (staff.canLogin) 'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['message'] ?? 'Failed to create staff');
    }

    // Force an immediate sync pull so SQLite gets the newly created user without waiting 30s
    // (Assuming SyncService handles its own loops, but we can do a quick manual pull here if needed)
  }

  Future<void> updateStaffLocally(StaffModel staff) async {
    final updated = staff.copyWith(updatedAt: DateTime.now(), isSynced: false);
    
    await _sqliteService.transaction((txn) async {
      await txn.update(
        'staff',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );

      await txn.insert('sync_queue', {
        'table_name': 'staff',
        'record_id': updated.id,
        'action': 'UPDATE',
        'data': jsonEncode(updated.toMap()),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'attempt_count': 0,
      });
    });
  }

  Future<void> deleteStaffLocally(String id) async {
    await _sqliteService.transaction((txn) async {
      await txn.update(
        'staff',
        {'is_deleted': 1, 'is_synced': 0, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [id],
      );

      await txn.insert('sync_queue', {
        'table_name': 'staff',
        'record_id': id,
        'action': 'UPDATE',
        'data': jsonEncode({'is_deleted': 1}),
        'created_at': DateTime.now().toIso8601String(),
        'synced': 0,
        'attempt_count': 0,
      });
    });
  }
}
