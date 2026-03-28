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
  String _selectedClass = 'All';
  
  // null = not marked, true = present, false = absent
  final Map<String, bool?> _attendanceState = {};
  bool _isSaving = false;

  int get _markedCount => _attendanceState.values.where((v) => v != null).length;
  int get _presentCount => _attendanceState.values.where((v) => v == true).length;
  int get _absentCount => _attendanceState.values.where((v) => v == false).length;

  void _submitBulkAttendance(List<dynamic> students) async {
    // Validate all students are marked
    final unmarked = students.where((s) => _attendanceState[s.id] == null).length;
    if (unmarked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$unmarked students not marked! Tap each student to mark.'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final records = students.map((s) => AttendanceModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${s.id}',
        studentId: s.id,
        classId: s.classId,
        date: _selectedDate,
        periodNumber: _periodNumber,
        status: _attendanceState[s.id] == true ? 'Present' : 'Absent',
        markedBy: 'teacher',
        deviceId: 'device_01',
      )).toList();

      await ref.read(attendanceRepositoryProvider).markBulkAttendance(records);
      ref.invalidate(dashboardMetricsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Saved! $_presentCount present, $_absentCount absent'),
            ]),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentRepositoryProvider).getAllStudents();

    return Scaffold(
      floatingActionButton: _isSaving
          ? const CircularProgressIndicator()
          : FloatingActionButton.extended(
              onPressed: () async {
                final students = await studentsAsync;
                _submitBulkAttendance(students);
              },
              icon: const Icon(Icons.save_rounded),
              label: Text('Save ($_markedCount)'),
              backgroundColor: _markedCount > 0 ? Colors.green : Colors.grey,
            ),
      body: FutureBuilder(
        future: studentsAsync,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

          final allStudents = snapshot.data ?? [];
          if (allStudents.isEmpty) {
            return const Center(child: Text('Add students first to mark attendance.'));
          }

          // Extract classes
          final classSet = <String>{'All'};
          for (final s in allStudents) {
            classSet.add(s.classId);
          }
          final classes = classSet.toList()..sort();

          // Filter
          final students = _selectedClass == 'All'
              ? allStudents
              : allStudents.where((s) => s.classId == _selectedClass).toList();

          return Column(
            children: [
              // Controls Bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.04),
                  border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Date picker
                        Expanded(
                          child: InkWell(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.withOpacity(0.2)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Period selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _periodNumber,
                              items: List.generate(8, (i) => DropdownMenuItem(
                                value: i + 1,
                                child: Text('P${i + 1}', style: const TextStyle(fontSize: 13)),
                              )),
                              onChanged: (v) => setState(() => _periodNumber = v ?? 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Class filter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedClass,
                              items: classes.map((c) => DropdownMenuItem(
                                value: c,
                                child: Text(c == 'All' ? 'All' : 'C$c', style: const TextStyle(fontSize: 13)),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedClass = v ?? 'All'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Stats bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statChip('Total', '${students.length}', Colors.blue),
                        _statChip('Present', '$_presentCount', Colors.green),
                        _statChip('Absent', '$_absentCount', Colors.red),
                        _statChip('Unmarked', '${students.length - _markedCount}', Colors.grey),
                      ],
                    ),
                  ],
                ),
              ),

              // Student List — NEUTRAL TOGGLES (no default)
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: students.length,
                  itemBuilder: (ctx, i) {
                    final student = students[i];
                    final state = _attendanceState[student.id]; // null = unmarked

                    Color bgColor;
                    if (state == true) {
                      bgColor = Colors.green.withOpacity(0.06);
                    } else if (state == false) {
                      bgColor = Colors.red.withOpacity(0.06);
                    } else {
                      bgColor = Colors.transparent;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: state == null ? Colors.grey.withOpacity(0.15) :
                                 state == true ? Colors.green.withOpacity(0.2) :
                                 Colors.red.withOpacity(0.2),
                        ),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: state == null ? Colors.grey.withOpacity(0.1) :
                                          state == true ? Colors.green.withOpacity(0.1) :
                                          Colors.red.withOpacity(0.1),
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: state == null ? Colors.grey : state == true ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text('Roll: ${student.rollNumber} • Class ${student.classId}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Present button
                            InkWell(
                              onTap: () => setState(() => _attendanceState[student.id] = true),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: state == true ? Colors.green : Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('P',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: state == true ? Colors.white : Colors.green,
                                    )),
                              ),
                            ),
                            const SizedBox(width: 6),
                            // Absent button
                            InkWell(
                              onTap: () => setState(() => _attendanceState[student.id] = false),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: state == false ? Colors.red : Colors.red.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text('A',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: state == false ? Colors.white : Colors.red,
                                    )),
                              ),
                            ),
                          ],
                        ),
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

  Widget _statChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
      ],
    );
  }
}
