import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/attendance_repository.dart';
import '../../../models/attendance_model.dart';
import '../../students/repositories/student_repository.dart';
import '../../dashboard/repositories/dashboard_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  int _periodNumber = 1;
  final Set<String> _presentStudentIds = {};
  bool _isSaving = false;

  void _submitBulkAttendance(List<dynamic> students) async {
    setState(() => _isSaving = true);
    try {
      final records = students.map((s) => AttendanceModel(
        id: DateTime.now().millisecondsSinceEpoch.toString() + s.id,
        studentId: s.id,
        classId: s.classId,
        date: _selectedDate,
        periodNumber: _periodNumber,
        status: _presentStudentIds.contains(s.id) ? 'present' : 'absent',
        markedBy: 'teacher_01', 
        deviceId: 'device_01',
      )).toList();

      await ref.read(attendanceRepositoryProvider).markBulkAttendance(records);

      // Explicitly trigger Dashboard refresh universally
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(content: Text('Bulk attendance saved!'), backgroundColor: Colors.green)
         );
      }
    } catch (e) {
      if (mounted) {
         // UI shows explicit exception or native popup
         showDialog(
           context: context,
           builder: (_) => AlertDialog(
             title: const Text('Error'),
             content: Text(e.toString()),
           ),
         );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fetch generic students to mock the list rendering natively
    final studentsAsync = ref.watch(studentRepositoryProvider).getAllStudents();

    return Scaffold(
      floatingActionButton: _isSaving 
          ? const CircularProgressIndicator()
          : FloatingActionButton.extended(
              onPressed: () async {
                 final students = await studentsAsync;
                 _submitBulkAttendance(students);
              },
              icon: const Icon(Icons.save),
              label: const Text('Save Form'),
            ),
      body: FutureBuilder(
        future: studentsAsync,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          
          final students = snapshot.data ?? [];
          if (students.isEmpty) return const Center(child: Text('Add students first to mark attendance.'));

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Period: $_periodNumber', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => setState(() => _periodNumber++),
                    )
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: students.length,
                  itemBuilder: (ctx, i) {
                    final student = students[i];
                    final isPresent = _presentStudentIds.contains(student.id);

                    return ListTile(
                      title: Text(student.name),
                      subtitle: Text('Roll: ${student.rollNumber}'),
                      trailing: Switch(
                        value: isPresent,
                        activeColor: Colors.green,
                        onChanged: (val) {
                          setState(() {
                            if (val) _presentStudentIds.add(student.id);
                            else _presentStudentIds.remove(student.id);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
