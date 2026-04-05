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

class _MarksScreenState extends ConsumerState<MarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Teacher's assigned data from timetable
  List<String> _assignedClasses = [];
  Map<String, List<String>> _classSubjects = {}; // classId -> [subjects]
  bool _isLoadingAssignments = true;

  String _selectedClass = '';
  String _selectedExamType = 'Quarterly';

  // For ranks tab
  bool _isRankLoading = false;
  List<Map<String, dynamic>> _rankings = [];

  static const _examTypes = ['Quarterly', 'Half-Yearly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAssignedClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignedClasses() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null || session.userId.isEmpty) {
      setState(() => _isLoadingAssignments = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/timetable/teacher/${session.userId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final timetable = List<Map<String, dynamic>>.from(data['timetable'] ?? []);

        final classSet = <String>{};
        final cSubjects = <String, Set<String>>{};

        for (final entry in timetable) {
          final classId = entry['class_id']?.toString() ?? '';
          final subject = entry['subject']?.toString() ?? '';
          if (classId.isNotEmpty) {
            classSet.add(classId);
            cSubjects.putIfAbsent(classId, () => <String>{});
            if (subject.isNotEmpty) cSubjects[classId]!.add(subject);
          }
        }

        final sorted = classSet.toList()
          ..sort((a, b) {
            final aNum = int.tryParse(a);
            final bNum = int.tryParse(b);
            if (aNum != null && bNum != null) return aNum.compareTo(bNum);
            return a.compareTo(b);
          });

        final subjectMap = <String, List<String>>{};
        for (final entry in cSubjects.entries) {
          subjectMap[entry.key] = entry.value.toList()..sort();
        }

        setState(() {
          _assignedClasses = sorted;
          _classSubjects = subjectMap;
          if (sorted.isNotEmpty) _selectedClass = sorted.first;
          _isLoadingAssignments = false;
        });
      } else {
        setState(() => _isLoadingAssignments = false);
      }
    } catch (e) {
      debugPrint('Load assignments error: $e');
      setState(() => _isLoadingAssignments = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Enter Marks'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.blue[700],
          tabs:  const [
            Tab(text: 'Enter Marks'),
            Tab(text: 'Class Ranks'),
          ],
        ),
      ),
      body: _isLoadingAssignments
          ? const Center(child: CircularProgressIndicator())
          : _assignedClasses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.school_rounded, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No classes assigned', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Ask admin to assign you in the timetable', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildEntryTab(),
                    _buildRanksTab(),
                  ],
                ),
    );
  }

  // ── TAB 1: Student List → Tap → Marks Entry ──
  Widget _buildEntryTab() {
    final studentsAsync = ref.watch(studentRepositoryProvider).getAllStudents(limit: 500, offset: 0);

    return Column(
      children: [
        // Class & Exam selector
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            // Class dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.withOpacity(0.15)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass,
                  items: _assignedClasses.map((c) {
                    final isNum = int.tryParse(c) != null;
                    return DropdownMenuItem(value: c, child: Text(
                      isNum ? 'Class $c' : c,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v ?? _assignedClasses.first),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Exam type
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.withOpacity(0.15)),
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
          ]),
        ),

        // Student list
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
                      Icon(Icons.person_search_rounded, size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('No students in this class', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final student = students[index];
                  final subjects = _classSubjects[_selectedClass] ?? [];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        child: Text('${index + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13)),
                      ),
                      title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Roll: ${student.rollNumber}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      trailing: const Icon(Icons.edit_note_rounded, color: Colors.blue, size: 22),
                      onTap: () => _showMarksEntryDialog(student, subjects),
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

  // ── Marks Entry Dialog for a specific student ──
  void _showMarksEntryDialog(dynamic student, List<String> subjects) {
    // If no subjects from timetable, show default list
    final availableSubjects = subjects.isNotEmpty
        ? subjects
        : ['Mathematics', 'English', 'Hindi', 'Science', 'Social Studies', 'Computer Science'];

    String selectedSubject = availableSubjects.first;
    final marksController = TextEditingController();
    final totalController = TextEditingController(text: '100');
    String examType = _selectedExamType;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue.withOpacity(0.1),
              child: Text(student.name[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(student.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                Text('Roll: ${student.rollNumber} • Class ${student.classId}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              // Exam type selector
              DropdownButtonFormField<String>(
                value: examType,
                items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => examType = v ?? 'Quarterly'),
                decoration: InputDecoration(
                  labelText: 'Exam Type',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  prefixIcon: const Icon(Icons.quiz_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              // Subject selector
              DropdownButtonFormField<String>(
                value: selectedSubject,
                items: availableSubjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                onChanged: (v) => setDialogState(() => selectedSubject = v ?? availableSubjects.first),
                decoration: InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                  prefixIcon: const Icon(Icons.book_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              // Marks input row
              Row(children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: marksController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Marks Obtained',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('/', style: TextStyle(fontSize: 20, color: Colors.grey)),
                ),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: totalController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Total',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: isSaving ? null : () async {
                final marksText = marksController.text.trim();
                final totalText = totalController.text.trim();
                if (marksText.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter marks'), backgroundColor: Colors.orange),
                  );
                  return;
                }

                final marks = double.tryParse(marksText) ?? 0;
                final total = double.tryParse(totalText) ?? 100;

                try {
                  ValidatorService.validateMarks(marks, total);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                try {
                  final db = await SQLiteService().database;
                  await db.insert('marks', {
                    'id': 'mark_${student.id}_${examType}_${selectedSubject}_${DateTime.now().millisecondsSinceEpoch}',
                    'student_id': student.id,
                    'class_id': _selectedClass,
                    'exam_date': DateTime.now().toIso8601String(),
                    'exam_type': examType,
                    'subject': selectedSubject,
                    'marks_obtained': marks,
                    'total_marks': total,
                    'grade': 'A', // TODO: auto compute grade
                    'device_id': 'device_01',
                    'is_synced': 0,
                    'is_deleted': 0,
                    'updated_at': DateTime.now().toIso8601String(),
                  });

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${student.name}: $selectedSubject — ${marks.toStringAsFixed(0)}/${total.toStringAsFixed(0)} saved ✅'),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ));
                  }
                } catch (e) {
                  setDialogState(() => isSaving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              icon: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 18),
              label: Text(isSaving ? 'Saving...' : 'Save Marks'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: Class Rankings ──
  Widget _buildRanksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedExamType,
                  items: _examTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) => setState(() => _selectedExamType = v ?? 'Quarterly'),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass,
                  items: _assignedClasses.map((c) {
                    final isNum = int.tryParse(c) != null;
                    return DropdownMenuItem(value: c, child: Text(isNum ? 'C$c' : c, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v ?? _assignedClasses.first),
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
          ]),
        ),
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
                    if (rank == 1) { rankColor = Colors.amber; rankIcon = Icons.emoji_events; }
                    else if (rank == 2) { rankColor = Colors.grey; rankIcon = Icons.emoji_events; }
                    else if (rank == 3) { rankColor = Colors.brown; rankIcon = Icons.emoji_events; }
                    else { rankColor = Colors.blue; rankIcon = Icons.tag; }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: rank <= 3 ? rankColor.withOpacity(0.06) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: rank <= 3 ? rankColor.withOpacity(0.2) : Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: rankColor.withOpacity(0.15),
                          child: rank <= 3
                              ? Icon(rankIcon, size: 18, color: rankColor)
                              : Text('#$rank', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: rankColor)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(student['student_name']?.toString() ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${percentage.toStringAsFixed(1)}% • Grade: $grade',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ]),
                        ),
                        Text('${student['total_obtained'] ?? 0}/${student['total_max'] ?? 0}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      ]),
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
