import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notice_model.dart';
import '../../../services/db/sqlite_service.dart';

/// Database-backed notices provider
final noticesListProvider = FutureProvider.autoDispose<List<NoticeModel>>((ref) async {
  try {
    final db = await SQLiteService().database;
    final rows = await db.query(
      'notices',
      where: 'is_deleted = 0',
      orderBy: 'posted_at DESC',
    );
    return rows.map((r) {
      // Handle bool/int conversions safely
      final map = Map<String, dynamic>.from(r);
      if (map['is_important'] is int) {
        map['is_important'] = map['is_important'] == 1;
      }
      return NoticeModel.fromJson(map);
    }).toList();
  } catch (e) {
    // Return empty list if table doesn't exist yet
    return [];
  }
});
