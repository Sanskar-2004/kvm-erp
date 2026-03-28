import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:developer';

import '../db/sqlite_service.dart';
import '../../features/students/repositories/student_repository.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../core/constants/app_constants.dart';

enum SyncStatus { pending, synced, failed }
int toDb(SyncStatus s) => s.index;
SyncStatus fromDb(int v) => SyncStatus.values[v];

final pendingCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final db = await ref.watch(syncServiceProvider)._dbService.database;
  final counts = await db.query('sync_queue', where: 'synced = ?', whereArgs: [toDb(SyncStatus.pending)]);
  return counts.length;
});

final failedCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final db = await ref.watch(syncServiceProvider)._dbService.database;
  final counts = await db.query('sync_queue', where: 'synced = ?', whereArgs: [toDb(SyncStatus.failed)]);
  return counts.length;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    SQLiteService(), 
    ref.watch(studentRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});

class SyncService {
  final SQLiteService _dbService;
  final StudentRepository _studentRepository;
  final AuthRepository _authRepository;
  bool _isSyncRunning = false;

  SyncService(this._dbService, this._studentRepository, this._authRepository);

  Future<void> runSyncSafe() async {
    if (_isSyncRunning) return;
    _isSyncRunning = true;
    try {
      await runSync();
    } catch(e) {
      log('Sync Frame Crashed: $e');
      rethrow;
    } finally {
      _isSyncRunning = false;
    }
  }

  Future<void> runSync() async {
    final session = await _authRepository.getSession();
    if (session == null) throw Exception("Cannot sync: User not authenticated natively.");
    final token = session.token;

    await pushSyncQueue(token);
    await fetchServerChanges(token);
    _studentRepository.invalidateStudentCache();
  }

  Future<void> retryFailedQueue() async {
    final db = await _dbService.database;
    await db.update(
      'sync_queue', 
      {'synced': toDb(SyncStatus.pending), 'attempt_count': 0}, 
      where: 'synced = ?', 
      whereArgs: [toDb(SyncStatus.failed)]
    );
    await runSyncSafe();
  }

  Future<void> pushSyncQueue(String token) async {
    final db = await _dbService.database;
    final queue = await db.query(
      'sync_queue', 
      where: 'synced = ? AND attempt_count < ?', 
      whereArgs: [toDb(SyncStatus.pending), 3]
    );

    if (queue.isEmpty) return;

    // 1. Build exactly the { "students": [], "attendance": [] } structure locally
    Map<String, List<Map<String, dynamic>>> payload = {};
    for (var job in queue) {
      final table = job['table_name'].toString();
      if (!payload.containsKey(table)) payload[table] = [];
      payload[table]!.add(jsonDecode(job['data'].toString()));
    }

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/sync/push'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Node Server explicitly handled ALL conflicts and inserts natively. 
        // We can safely mark local queues globally complete!
        for (var job in queue) {
           await db.update('sync_queue', {'synced': toDb(SyncStatus.synced), 'last_error': null}, where: 'id = ?', whereArgs: [job['id']]);
           await db.update(job['table_name'].toString(), {'is_synced': 1}, where: 'id = ?', whereArgs: [job['record_id']]);
        }
      } else {
        throw Exception("Server Rejected Push: ${response.body}");
      }
    } catch (e) {
      log('Push Queue Crash: $e');
      for (var job in queue) {
        final currentAttempts = int.parse(job['attempt_count'].toString());
        final newAttempts = currentAttempts + 1;
        await db.update(
          'sync_queue', 
          {
             'attempt_count': newAttempts, 
             'last_error': e.toString(),
             'synced': newAttempts >= 3 ? toDb(SyncStatus.failed) : toDb(SyncStatus.pending)
          }, 
          where: 'id = ?', 
          whereArgs: [job['id']]
        );
      }
    }
  }

  Future<void> fetchServerChanges(String token) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSyncEpoch = prefs.getInt('last_sync_at') ?? 0;
    final lastSyncDate = DateTime.fromMillisecondsSinceEpoch(lastSyncEpoch).toUtc().toIso8601String();

    try {
       final response = await http.get(
          Uri.parse('$BASE_URL/sync/pull?lastSync=$lastSyncDate'),
          headers: { 'Authorization': 'Bearer $token' },
       );

       if (response.statusCode == 200) {
          final json = jsonDecode(response.body);
          final serverDataMap = json['data'] as Map<String, dynamic>;
          final db = await _dbService.database;

          await db.transaction((txn) async {
             for (final table in serverDataMap.keys) {
                if (table == 'serverTime') continue;

                final List<dynamic> rows = serverDataMap[table];
                for (final row in rows) {
                   // Ensure local database structurally mirrors changes correctly dropping older local rows
                   final localResults = await txn.query(table, where: 'id = ?', whereArgs: [row['id']]);
                   if (localResults.isEmpty) {
                      if (row['is_deleted'] != 1) { // Drop dead cloud references
                         await txn.insert(table, Map<String, dynamic>.from(row));
                      }
                   } else {
                      final localUpdatedAt = DateTime.parse(localResults.first['updated_at'].toString());
                      final serverUpdatedAt = DateTime.parse(row['updated_at'].toString());
                      
                      if (serverUpdatedAt.isAfter(localUpdatedAt)) {
                         await txn.update(table, Map<String, dynamic>.from(row), where: 'id = ?', whereArgs: [row['id']]);
                      }
                   }
                }
             }
          });
       } else {
         throw Exception("Pull Error: ${response.body}");
       }
    } catch (e) {
       log('Pull Sync Crash: $e');
       rethrow;
    }
  }
}
