import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/sqlite_service.dart';

final feeAnalyticsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((ref, academicYear) async {
  return await SQLiteService().getFeeAnalytics(academicYear: academicYear);
});
