import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/academic_utils.dart';
import '../../../core/utils/validator_service.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../students/repositories/student_repository.dart';
import '../../../services/db/sqlite_service.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen> {
  String _selectedExamType = 'Quarterly';
  String _selectedClass = '10';
  String _selectedSubject = 'Mathematics';
  bool _isSaving = false;
  bool _isRankLoading = false;

  final Map<String, TextEditingController> _marksControllers = {};
  final Map<String, TextEditingController> _totalControllers = {};
  List<Map<String, dynamic>> _rankings = [];

  static const _examTypes = ['Quarterly', 'Half-Yearly', 'Yearly'];
  static const _subjects = ['Mathematics', 'English', 'Hindi', 'Science', 'Social Studies',
    'Computer Science', 'Physical Education', 'Art'];
  final _classes = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentRepositoryProvider).getAllStudents();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            // Tab Bar
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                indicator: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: '  Enter Marks  '),
                  Tab(text: '  Class Ranks  '),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Tab Content
            Expanded(
              child: TabBarView(
                children: [
                  _buildEntryTab(studentsAsync),
                  _buildRanksTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: Marks Entry ──
  Widget _buildEntryTab(Future<List<dynamic>> studentsAsync) {
    return Column(
      children: [
        // Selectors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Exam Type
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedExamType,
                      isExpanded: true,
                      items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _selectedExamType = v ?? 'Quarterly'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Class
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.withOpacity(0.15)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('C$c', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedClass = v ?? '10'),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Subject
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.withOpacity(0.15)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSubject,
                      isExpanded: true,
                      items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 11)))).toList(),
                      onChanged: (v) => setState(() => _selectedSubject = v ?? 'Mathematics'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Student List
        Expanded(
          child: FutureBuilder(
            future: studentsAsync,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final allStudents = snapshot.data ?? [];
              final students = allStudents.where((s) => s.classId == _selectedClass).toList();

              if (students.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No students in Class $_selectedClass', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: students.length + 1, // +1 for save button
                itemBuilder: (context, index) {
                  if (index == students.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : () => _saveMarks(students),
                        icon: _isSaving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(_isSaving ? 'Saving...' : 'Save All Marks'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    );
                  }

                  final student = students[index];
                  _marksControllers.putIfAbsent(student.id, () => TextEditingController());
                  _totalControllers.putIfAbsent(student.id, () => TextEditingController(text: '100'));

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        // Student info
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text('Roll: ${student.rollNumber}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        // Marks input
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _marksControllers[student.id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: 'Marks',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text('/', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ),
                        // Total input
                        SizedBox(
                          width: 50,
                          child: TextField(
                            controller: _totalControllers[student.id],
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: '100',
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveMarks(List<dynamic> students) async {
    setState(() => _isSaving = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      for (final student in students) {
        final marksText = _marksControllers[student.id]?.text ?? '';
        final totalText = _totalControllers[student.id]?.text ?? '100';
        if (marksText.isEmpty) continue;

        final marks = double.tryParse(marksText) ?? 0;
        final total = double.tryParse(totalText) ?? 100;

        ValidatorService.validateMarks(marks, total);

        // Push to local SQLite
        final db = await SQLiteService().database;
        await db.insert('marks', {
          'id': 'mark_${student.id}_${_selectedExamType}_${_selectedSubject}_${DateTime.now().millisecondsSinceEpoch}',
          'student_id': student.id,
          'date': DateTime.now().toIso8601String(),
          'exam_type': _selectedExamType,
          'subject': _selectedSubject,
          'marks_obtained': marks,
          'total_marks': total,
          'device_id': 'device_01',
          'is_synced': 0,
          'is_deleted': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Marks saved ✅'),
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

  // ── TAB 2: Class Rankings ──
  Widget _buildRanksTab() {
    return Column(
      children: [
        // Selectors
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedExamType,
                      isExpanded: true,
                      items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _selectedExamType = v ?? 'Quarterly'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedClass,
                    items: _classes.map((c) => DropdownMenuItem(value: c, child: Text('C$c', style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _selectedClass = v ?? '10'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isRankLoading ? null : _fetchRanks,
                icon: _isRankLoading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.leaderboard_rounded, size: 16),
                label: const Text('Calculate', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Rankings List
        Expanded(
          child: _rankings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Select exam type and click Calculate', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _rankings.length,
                  itemBuilder: (context, index) {
                    final student = _rankings[index];
                    final rank = student['rank'] ?? (index + 1);
                    final percentage = double.tryParse(student['percentage']?.toString() ?? '0') ?? 0;
                    final grade = AcademicUtils.generateGrade(percentage);

                    Color rankColor;
                    IconData rankIcon;
                    if (rank == 1) {
                      rankColor = Colors.amber; rankIcon = Icons.emoji_events;
                    } else if (rank == 2) {
                      rankColor = Colors.grey; rankIcon = Icons.emoji_events;
                    } else if (rank == 3) {
                      rankColor = Colors.brown; rankIcon = Icons.emoji_events;
                    } else {
                      rankColor = Colors.blue; rankIcon = Icons.tag;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: rank <= 3 ? rankColor.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: rank <= 3 ? rankColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: rankColor.withOpacity(0.15),
                            child: rank <= 3
                                ? Icon(rankIcon, size: 18, color: rankColor)
                                : Text('#$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankColor)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student['student_name']?.toString() ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                Text('${percentage.toStringAsFixed(1)}% • Grade: $grade',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                              ],
                            ),
                          ),
                          Text('${student['total_obtained'] ?? 0}/${student['total_max'] ?? 0}',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _fetchRanks() async {
    setState(() => _isRankLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      final response = await http.get(
        Uri.parse('$BASE_URL/admin/class-ranks/$_selectedClass/$_selectedExamType'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _rankings = List<Map<String, dynamic>>.from(data['rankings'] ?? []);
          _isRankLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isRankLoading = false);
      debugPrint('Fetch ranks error: $e');
    }
  }
}
