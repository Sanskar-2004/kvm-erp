import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/sqlite_service.dart';

final feeAnalyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return await SQLiteService().getFeeAnalytics();
});
