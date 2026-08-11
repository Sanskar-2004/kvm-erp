import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/staff_model.dart';
import '../../../services/db/sqlite_service.dart';
import '../../attendance/repositories/attendance_repository.dart';
import '../../../core/constants/app_constants.dart';
import 'package:http/http.dart' as http;
import '../../auth/repositories/auth_repository.dart';
import '../../../services/sync/sync_service.dart';

import 'package:flutter/foundation.dart';

final staffRepositoryProvider = Provider((ref) => StaffRepository(
      ref.read(sqliteServiceProvider),
      ref,
    ));

class StaffRepository {
  final SQLiteService _sqliteService;
  final Ref _ref;

  StaffRepository(this._sqliteService, this._ref);

  Future<List<StaffModel>> getAllStaff() async {
    if (kIsWeb) {
      final webStaff = await _fetchStaffFromApi();
      if (webStaff != null && webStaff.isNotEmpty) return webStaff;
    }

    try {
      final result = await _sqliteService.query(
        'staff',
        where: 'is_deleted = 0 OR is_deleted IS NULL',
        orderBy: 'name ASC',
      );
      final list = result.map((e) => StaffModel.fromMap(e)).toList();
      if (list.isNotEmpty) return list;
    } catch (e) {
      debugPrint("SQLite staff query error: $e");
    }

    final fallbackStaff = await _fetchStaffFromApi();
    return fallbackStaff ?? [];
  }

  Future<List<StaffModel>> getStaffByRole(String role) async {
    final all = await getAllStaff();
    if (role.toLowerCase() == 'all') return all;
    return all.where((s) => s.role.toLowerCase() == role.toLowerCase()).toList();
  }

  Future<List<StaffModel>?> _fetchStaffFromApi() async {
    try {
      final session = await _ref.read(authRepositoryProvider).getSession();
      if (session == null) return null;

      final response = await http.get(
        Uri.parse('$BASE_URL/staff'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final List list = json['data'] ?? [];
        return list.map((e) => StaffModel.fromMap(Map<String, dynamic>.from(e))).toList();
      } else {
        final syncRes = await http.get(
          Uri.parse('$BASE_URL/sync/pull?lastSync=2000-01-01T00:00:00.000Z'),
          headers: {'Authorization': 'Bearer ${session.token}'},
        );
        if (syncRes.statusCode == 200) {
          final json = jsonDecode(syncRes.body);
          final List list = json['data']?['staff'] ?? [];
          return list.map((e) => StaffModel.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      }
    } catch (e) {
      debugPrint("API staff fetch error: $e");
    }
    return null;
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

    final body = jsonDecode(response.body);
    final finalStaff = staff.copyWith(
      userId: body['user_id'], // Retrieve the backend-generated user_id
      canLogin: staff.canLogin, 
      isSynced: true,
      updatedAt: DateTime.now()
    );

    await _sqliteService.insert('staff', finalStaff.toMap());
    
    // Force an immediate sync pull to grab the 'users' entry if it was spawned locally 
    try { 
        await _ref.read(syncServiceProvider).runSyncSafe(); 
    } catch (_) {}
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
