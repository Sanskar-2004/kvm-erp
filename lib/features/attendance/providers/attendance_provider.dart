import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/student_model.dart';

class AttendanceState {
  final String selectedClass;
  final List<StudentModel> students;
  final Map<String, String> statuses; // studentId -> present/absent/late

  const AttendanceState({
    this.selectedClass = '10-A',
    this.students = const [],
    this.statuses = const {},
  });

  AttendanceState copyWith({
    String? selectedClass,
    List<StudentModel>? students,
    Map<String, String>? statuses,
  }) {
    return AttendanceState(
      selectedClass: selectedClass ?? this.selectedClass,
      students: students ?? this.students,
      statuses: statuses ?? this.statuses,
    );
  }
}

class AttendanceNotifier extends StateNotifier<AttendanceState> {
  AttendanceNotifier() : super(const AttendanceState());

  void selectClass(String className) {
    // TODO: Fetch students for selected class from DB
    state = state.copyWith(selectedClass: className, students: [], statuses: {});
  }

  void markAttendance(String studentId, String status) {
    final updated = Map<String, String>.from(state.statuses);
    updated[studentId] = status;
    state = state.copyWith(statuses: updated);
  }
}

final attendanceProvider =
    StateNotifierProvider<AttendanceNotifier, AttendanceState>(
        (ref) => AttendanceNotifier());
