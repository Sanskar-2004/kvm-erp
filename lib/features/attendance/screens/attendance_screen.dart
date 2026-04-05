import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../repositories/attendance_repository.dart';
import '../../../models/attendance_model.dart';
import '../../students/repositories/student_repository.dart';
import '../../dashboard/repositories/dashboard_repository.dart';
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../staff/repositories/assignment_repository.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  int _periodNumber = 1;
  String _selectedClass = '';

  // Teacher's assigned classes from timetable
  List<String> _assignedClasses = [];
  bool _isLoadingClasses = true;

  // null = not marked, true = present, false = absent
  final Map<String, bool?> _attendanceState = {};
  bool _isSaving = false;

  int get _markedCount => _attendanceState.values.where((v) => v != null).length;
  int get _presentCount => _attendanceState.values.where((v) => v == true).length;
  int get _absentCount => _attendanceState.values.where((v) => v == false).length;

  @override
  void initState() {
    super.initState();
    _loadAssignedClasses();
  }

  Future<void> _loadAssignedClasses() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null || session.userId.isEmpty) {
      // Fallback: show all classes if no userId
      setState(() {
        _assignedClasses = [];
        _isLoadingClasses = false;
      });
      return;
    }

    try {
      // Phase 3 Architecture: Read exact assignments
      // But we need the staff_id. We only have user_id in auth.
      // Actually /api/assignments?staff_id= wants staff_id.
      // Fallback to fetch assignments where user_id matches via custom endpoint?
      // For now, let's query the assignments API directly using /assignments?user_id= session.userId if backend supports it.
      // Wait, getAssignments doesn't support user_id yet. Let's send a request and let backend handle it, or we fetch the staff row first.
      
      // Let's use custom logic: GET /api/staff then find my id?
      final staffRes = await http.get(Uri.parse('$BASE_URL/staff'), headers: {'Authorization': 'Bearer ${session.token}'});
      String? myStaffId;
      if (staffRes.statusCode == 200) {
         final sList = jsonDecode(staffRes.body)['data'] as List;
         final me = sList.firstWhere((s) => s['user_id']?.toString() == session.userId, orElse: () => null);
         if (me != null) myStaffId = me['id'];
      }

      if (myStaffId == null) {
         setState(() => _isLoadingClasses = false);
         return;
      }

      final assigns = await ref.read(assignmentRepositoryProvider).getAssignmentsByStaff(myStaffId);
      final classSet = <String>{};
      for (final a in assigns) {
        if (a.isClassTeacher) {
          classSet.add(a.classId); // Grant full rights only to class teachers, or any assigned teacher
        }
        // If we want any assigned teacher to take attendance, do classSet.add(a.classId) unconditionally
        classSet.add(a.classId);
      }

      final sorted = classSet.toList()..sort((a, b) {
        final aNum = int.tryParse(a);
        final bNum = int.tryParse(b);
        if (aNum != null && bNum != null) return aNum.compareTo(bNum);
        return a.compareTo(b);
      });

      setState(() {
        _assignedClasses = sorted;
        if (sorted.isNotEmpty) _selectedClass = sorted.first;
        _isLoadingClasses = false;
      });
    } catch (_) {
      setState(() => _isLoadingClasses = false);
    }
  }

  void _submitBulkAttendance(List<dynamic> students) async {
    final unmarked = students.where((s) => _attendanceState[s.id] == null).length;
    if (unmarked > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$unmarked students not marked! Tap P or A for each student.'),
        backgroundColor: Colors.orange[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Saved! $_presentCount present, $_absentCount absent'),
          ]),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
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
    final studentsAsync = ref.watch(studentRepositoryProvider).getAllStudents(limit: 500, offset: 0);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Mark Attendance'),
      ),
      floatingActionButton: _isSaving
          ? const CircularProgressIndicator()
          : FloatingActionButton.extended(
              heroTag: null,
              onPressed: () async {
                final allStudents = await studentsAsync;
                final students = _selectedClass.isEmpty
                    ? allStudents
                    : allStudents.where((s) => s.classId == _selectedClass).toList();
                _submitBulkAttendance(students);
              },
              icon: const Icon(Icons.save_rounded),
              label: Text('Save ($_markedCount)'),
              backgroundColor: _markedCount > 0 ? Colors.green : Colors.grey,
            ),
      body: _isLoadingClasses
          ? const Center(child: CircularProgressIndicator())
          : _assignedClasses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No classes assigned', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Ask admin to assign you in the timetable', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                )
              : FutureBuilder(
                  future: studentsAsync,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));

                    final allStudents = snapshot.data ?? [];
                    // Filter to only assigned class
                    final students = allStudents.where((s) => s.classId == _selectedClass).toList();

                    return Column(
                      children: [
                        // Controls Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.04),
                            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                          ),
                          child: Column(children: [
                            Row(children: [
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
                                    child: Row(children: [
                                      const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                      ),
                                    ]),
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
                              // Class filter — only assigned classes
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.green.withOpacity(0.2)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedClass,
                                    items: _assignedClasses.map((c) {
                                      final isNum = int.tryParse(c) != null;
                                      return DropdownMenuItem(
                                        value: c,
                                        child: Text(isNum ? 'C $c' : c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      );
                                    }).toList(),
                                    onChanged: (v) => setState(() {
                                      _selectedClass = v ?? _assignedClasses.first;
                                      _attendanceState.clear();
                                    }),
                                  ),
                                ),
                              ),
                            ]),
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
                          ]),
                        ),

                        // Student List
                        Expanded(
                          child: students.isEmpty
                              ? Center(child: Text('No students in this class', style: TextStyle(color: Colors.grey[500])))
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  itemCount: students.length,
                                  itemBuilder: (ctx, i) {
                                    final student = students[i];
                                    final state = _attendanceState[student.id];

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
                                          color: state == null ? Colors.grey.withOpacity(0.15)
                                              : state == true ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                        ),
                                      ),
                                      child: ListTile(
                                        dense: true,
                                        leading: CircleAvatar(
                                          radius: 16,
                                          backgroundColor: state == null ? Colors.grey.withOpacity(0.1)
                                              : state == true ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                          child: Text('${i + 1}', style: TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.bold,
                                            color: state == null ? Colors.grey : state == true ? Colors.green : Colors.red,
                                          )),
                                        ),
                                        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                        subtitle: Text('Roll: ${student.rollNumber}',
                                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => setState(() => _attendanceState[student.id] = true),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: state == true ? Colors.green : Colors.green.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text('P', style: TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 13,
                                                  color: state == true ? Colors.white : Colors.green,
                                                )),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            InkWell(
                                              onTap: () => setState(() => _attendanceState[student.id] = false),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: state == false ? Colors.red : Colors.red.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text('A', style: TextStyle(
                                                  fontWeight: FontWeight.bold, fontSize: 13,
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
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 10)),
    ]);
  }
}
