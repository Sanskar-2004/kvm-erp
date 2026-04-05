import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../staff/repositories/assignment_repository.dart';
import '../../../models/staff_assignment_model.dart';
import '../../../services/db/sqlite_service.dart';

// 1. Assignments list for a specific class
final classAssignmentsProvider = FutureProvider.family<List<StaffAssignmentModel>, String>((ref, classId) async {
  return await ref.read(assignmentRepositoryProvider).getAssignmentsByClass(classId);
});

// 2. Timetable data from Cloud API (or SQLite if refactored)
final classTimetableProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, classId) async {
  final session = await ref.read(authRepositoryProvider).getSession();
  if (session == null) throw Exception("Unauthorized to view timetable");

  final response = await http.get(
    Uri.parse('$BASE_URL/timetable/class/$classId'),
    headers: {'Authorization': 'Bearer ${session.token}'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['timetable'] ?? []);
  } else {
    throw Exception("Failed to load timetable");
  }
});

// 3. Insights aggregator
final classInsightsProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, classId) async {
  final assignments = await ref.watch(classAssignmentsProvider(classId).future);
  final timetable = await ref.watch(classTimetableProvider(classId).future);

  final bool hasClassTeacher = assignments.any((a) => a.isClassTeacher);
  
  // Calculate teaching load vs limits
  final List<Map<String, dynamic>> overloadedStaff = [];
  final Map<String, int> staffAllocatedPeriods = {};
  
  for (final period in timetable) {
    final teacherId = period['teacher_id'];
    if (teacherId != null) {
      staffAllocatedPeriods[teacherId.toString()] = (staffAllocatedPeriods[teacherId.toString()] ?? 0) + 1;
    }
  }

  for (final a in assignments) {
    final assignedPeriods = staffAllocatedPeriods[a.staffId] ?? 0;
    if (assignedPeriods > a.maxPeriodsPerWeek) {
      overloadedStaff.add({
        'teacher_name': a.staffName,
        'subject': a.subject,
        'assigned': assignedPeriods,
        'max': a.maxPeriodsPerWeek,
      });
    }
  }

  // Coverage % calculation (Assuming 42 slots per week: 6 days * 7 periods)
  final double coveragePercent = timetable.length / 42.0;

  return {
    'has_class_teacher': hasClassTeacher,
    'assigned_subjects_count': assignments.length,
    'coverage_percent': coveragePercent.clamp(0.0, 1.0),
    'overloaded_staff': overloadedStaff,
    'total_scheduled_periods': timetable.length,
  };
});
