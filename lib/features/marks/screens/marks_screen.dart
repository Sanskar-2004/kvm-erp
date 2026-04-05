import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/academic_utils.dart';
import '../../../core/utils/validator_service.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../students/repositories/student_repository.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../models/student_model.dart';

class MarksScreen extends ConsumerStatefulWidget {
  const MarksScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MarksScreen> createState() => _MarksScreenState();
}

class _MarksScreenState extends ConsumerState<MarksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<String> _assignedClasses = [];
  Map<String, List<String>> _classSubjects = {};
  bool _isLoadingAssignments = true;

  String _selectedClass = '';
  String _selectedExamType = 'Quarterly';

  // Marks sheet data: studentId -> subject -> marks
  Map<String, Map<String, double?>> _marksGrid = {};
  List<StudentModel> _classStudents = [];
  List<String> _currentSubjects = [];
  bool _isLoadingSheet = false;

  // Ranks
  bool _isRankLoading = false;
  List<Map<String, dynamic>> _rankings = [];

  static const _examTypes = ['Quarterly', 'Half-Yearly', 'Yearly'];
  static const _defaultSubjects = [
    'Mathematics',
    'English',
    'Hindi',
    'Science',
    'Social Studies',
    'Computer Science'
  ];

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
        final timetable =
            List<Map<String, dynamic>>.from(data['timetable'] ?? []);

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

        if (sorted.isNotEmpty) _loadMarksSheet();
      } else {
        setState(() => _isLoadingAssignments = false);
      }
    } catch (e) {
      debugPrint('Load assignments error: $e');
      setState(() => _isLoadingAssignments = false);
    }
  }

  Future<void> _loadMarksSheet() async {
    if (_selectedClass.isEmpty) return;
    setState(() => _isLoadingSheet = true);

    try {
      // 1. Get students for this class
      final students = await ref
          .read(studentRepositoryProvider)
          .getAllStudents(limit: 500, offset: 0);
      final classStudents = students
          .where((s) => s.classId == _selectedClass)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      // 2. Get subjects
      final subjects =
          _classSubjects[_selectedClass] ?? (_defaultSubjects.toList());

      // 3. Load existing marks from SQLite
      final db = await SQLiteService().database;
      final grid = <String, Map<String, double?>>{};
      for (final s in classStudents) {
        grid[s.id] = {};
        for (final subj in subjects) {
          grid[s.id]![subj] = null;
        }
      }

      final existingMarks = await db.query(
        'marks',
        where: 'class_id = ? AND exam_type = ? AND is_deleted = 0',
        whereArgs: [_selectedClass, _selectedExamType],
      );

      for (final row in existingMarks) {
        final sid = row['student_id']?.toString() ?? '';
        final subj = row['subject']?.toString() ?? '';
        final marks = double.tryParse(row['marks_obtained']?.toString() ?? '');
        if (grid.containsKey(sid) && grid[sid]!.containsKey(subj)) {
          grid[sid]![subj] = marks;
        }
      }

      setState(() {
        _classStudents = classStudents;
        _currentSubjects = subjects;
        _marksGrid = grid;
        _isLoadingSheet = false;
      });
    } catch (e) {
      debugPrint('Load sheet error: $e');
      setState(() => _isLoadingSheet = false);
    }
  }

  Future<void> _upsertMark(
      StudentModel student, String subject, double marks) async {
    try {
      final db = await SQLiteService().database;
      final id = 'mark_${student.id}_${_selectedExamType}_${subject}';
      final total = 100.0;
      ValidatorService.validateMarks(marks, total);

      await db.insert(
        'marks',
        {
          'id': id,
          'student_id': student.id,
          'class_id': _selectedClass,
          'exam_date': DateTime.now().toIso8601String(),
          'exam_type': _selectedExamType,
          'subject': subject,
          'marks_obtained': marks,
          'total_marks': total,
          'grade': AcademicUtils.generateGrade(
              AcademicUtils.calculatePercentage(marks, total)),
          'device_id': 'device_01',
          'is_synced': 0,
          'is_deleted': 0,
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      setState(() {
        _marksGrid[student.id] ??= {};
        _marksGrid[student.id]![subject] = marks;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context))
            : null,
        title: const Text('Marks Manager'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue[800],
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: Colors.blue[700],
          tabs: const [
            Tab(text: 'Marks Sheet'),
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
                      Icon(Icons.school_rounded,
                          size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No classes assigned',
                          style:
                              TextStyle(color: Colors.grey[500], fontSize: 16)),
                      const SizedBox(height: 8),
                      Text('Ask admin to assign you in the timetable',
                          style:
                              TextStyle(color: Colors.grey[400], fontSize: 12)),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSheetTab(),
                    _buildRanksTab(),
                  ],
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 1: SPREADSHEET MARKS ENTRY
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildSheetTab() {
    return Column(
      children: [
        // ── Selectors ──
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[50],
          child: Row(children: [
            _buildPill('Class', _assignedClasses, _selectedClass, Colors.blue,
                (v) {
              setState(() => _selectedClass = v);
              _loadMarksSheet();
            }),
            const SizedBox(width: 10),
            _buildPill('Exam', _examTypes, _selectedExamType, Colors.purple,
                (v) {
              setState(() => _selectedExamType = v);
              _loadMarksSheet();
            }),
          ]),
        ),

        // ── Sheet ──
        Expanded(
          child: _isLoadingSheet
              ? const Center(child: CircularProgressIndicator())
              : _classStudents.isEmpty
                  ? Center(
                      child: Text('No students in Class $_selectedClass',
                          style: TextStyle(color: Colors.grey[500])))
                  : _buildDataGrid(),
        ),
      ],
    );
  }

  Widget _buildPill(String label, List<String> items, String value, Color color,
      ValueChanged<String> onChanged) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            items: items
                .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(label == 'Class' ? 'Class $e' : e,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600))))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDataGrid() {
    final subjects = _currentSubjects;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: 140 + (subjects.length * 80) + 80,
        child: Column(
          children: [
            // ── Header row ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              color: Colors.indigo[50],
              child: Row(
                children: [
                  SizedBox(
                      width: 140,
                      child: Text('Student',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.indigo[800]))),
                  ...subjects.map((s) => SizedBox(
                      width: 80,
                      child: Text(_shortSubject(s),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.indigo[700])))),
                  SizedBox(
                      width: 80,
                      child: Text('Total',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.green[800]))),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Student rows ──
            Expanded(
              child: ListView.builder(
                itemCount: _classStudents.length,
                itemBuilder: (context, index) {
                  final student = _classStudents[index];
                  final studentMarks = _marksGrid[student.id] ?? {};
                  double total = 0;
                  int filled = 0;
                  for (final subj in subjects) {
                    final m = studentMarks[subj];
                    if (m != null) {
                      total += m;
                      filled++;
                    }
                  }

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    decoration: BoxDecoration(
                      color: index.isEven ? Colors.white : Colors.grey[50],
                      border: Border(
                          bottom:
                              BorderSide(color: Colors.grey.withOpacity(0.1))),
                    ),
                    child: Row(
                      children: [
                        // Student name
                        SizedBox(
                          width: 140,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis),
                              Text('Roll: ${student.rollNumber}',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.grey[500])),
                            ],
                          ),
                        ),
                        // Subject cells
                        ...subjects.map((subj) {
                          final val = studentMarks[subj];
                          return GestureDetector(
                            onTap: () => _showCellEditor(student, subj, val),
                            child: Container(
                              width: 80,
                              height: 36,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: val != null
                                    ? (val >= 33
                                        ? Colors.green.withOpacity(0.08)
                                        : Colors.red.withOpacity(0.08))
                                    : Colors.grey.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: val != null
                                        ? Colors.green.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.15)),
                              ),
                              alignment: Alignment.center,
                              child: val != null
                                  ? Text(val.toStringAsFixed(0),
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: val >= 33
                                              ? Colors.green[800]
                                              : Colors.red[700]))
                                  : Icon(Icons.edit,
                                      size: 14, color: Colors.grey[400]),
                            ),
                          );
                        }),
                        // Total cell
                        Container(
                          width: 80,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: filled == subjects.length
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            filled > 0 ? total.toStringAsFixed(0) : '—',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: filled == subjects.length
                                    ? Colors.green[800]
                                    : Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _shortSubject(String s) {
    const map = {
      'Mathematics': 'Math',
      'English': 'Eng',
      'Hindi': 'Hin',
      'Science': 'Sci',
      'Social Studies': 'SSt',
      'Computer Science': 'CS',
      'Physical Education': 'PE',
    };
    return map[s] ?? (s.length > 5 ? s.substring(0, 5) : s);
  }

  void _showCellEditor(StudentModel student, String subject, double? current) {
    final controller =
        TextEditingController(text: current?.toStringAsFixed(0) ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('${student.name} — $subject',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$_selectedExamType • Class $_selectedClass',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: '/ 100',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: (val) {
                final marks = double.tryParse(val);
                if (marks != null) {
                  _upsertMark(student, subject, marks);
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final marks = double.tryParse(controller.text);
              if (marks != null) {
                _upsertMark(student, subject, marks);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      '${student.name} — $subject: ${marks.toStringAsFixed(0)}/100 saved ✅'),
                  backgroundColor: Colors.green[700],
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white),
            child: Text(current != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TAB 2: CLASS RANKS
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildRanksTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _buildPill('Exam', _examTypes, _selectedExamType, Colors.purple,
                (v) {
              setState(() => _selectedExamType = v);
            }),
            const SizedBox(width: 8),
            _buildPill('Class', _assignedClasses, _selectedClass, Colors.blue,
                (v) {
              setState(() => _selectedClass = v);
            }),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isRankLoading ? null : _fetchRanks,
              icon: _isRankLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.leaderboard_rounded, size: 16),
              label: const Text('Calculate', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
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
                      Icon(Icons.emoji_events_rounded,
                          size: 48, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Text('Select exam type and click Calculate',
                          style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _rankings.length,
                  itemBuilder: (context, index) {
                    final student = _rankings[index];
                    final rank =
                        int.tryParse(student['rank']?.toString() ?? '') ??
                            (index + 1);
                    final percentage = double.tryParse(
                            student['percentage']?.toString() ?? '0') ??
                        0;
                    final grade = AcademicUtils.generateGrade(percentage);

                    Color rankColor;
                    IconData rankIcon;
                    if (rank == 1) {
                      rankColor = Colors.amber;
                      rankIcon = Icons.emoji_events;
                    } else if (rank == 2) {
                      rankColor = Colors.grey;
                      rankIcon = Icons.emoji_events;
                    } else if (rank == 3) {
                      rankColor = Colors.brown;
                      rankIcon = Icons.emoji_events;
                    } else {
                      rankColor = Colors.blue;
                      rankIcon = Icons.tag;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: rank <= 3
                            ? rankColor.withOpacity(0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: rank <= 3
                                ? rankColor.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: rankColor.withOpacity(0.15),
                          child: rank <= 3
                              ? Icon(rankIcon, size: 18, color: rankColor)
                              : Text('#$rank',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: rankColor)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    student['student_name']?.toString() ??
                                        'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14)),
                                Text(
                                    '${percentage.toStringAsFixed(1)}% • Grade: $grade',
                                    style: TextStyle(
                                        fontSize: 12, color: Colors.grey[500])),
                              ]),
                        ),
                        Text(
                            '${student['total_obtained'] ?? 0}/${student['total_max'] ?? 0}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500)),
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
      final db = await SQLiteService().database;

      // Aggregate marks per student from LOCAL SQLite
      final results = await db.rawQuery('''
        SELECT m.student_id, s.name AS student_name,
               SUM(m.marks_obtained) AS total_obtained,
               SUM(m.total_marks) AS total_max,
               ROUND(CAST(SUM(m.marks_obtained) AS REAL) / MAX(SUM(m.total_marks), 1) * 100, 2) AS percentage
        FROM marks m
        JOIN students s ON s.id = m.student_id
        WHERE s.class_id = ? AND m.exam_type = ? AND m.is_deleted = 0
        GROUP BY m.student_id, s.name
        ORDER BY percentage DESC
      ''', [_selectedClass, _selectedExamType]);

      // Assign ranks with tie support
      final ranked = <Map<String, dynamic>>[];
      int rank = 1;
      for (int i = 0; i < results.length; i++) {
        final row = Map<String, dynamic>.from(results[i]);
        if (i > 0) {
          final prevPct = double.tryParse(
                  results[i - 1]['percentage']?.toString() ?? '0') ??
              0;
          final currPct =
              double.tryParse(row['percentage']?.toString() ?? '0') ?? 0;
          if (currPct < prevPct) rank = i + 1;
        }
        row['rank'] = rank;
        ranked.add(row);
      }

      setState(() {
        _rankings = ranked;
        _isRankLoading = false;
      });

      if (ranked.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'No marks found for Class $_selectedClass — $_selectedExamType'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isRankLoading = false);
      debugPrint('Fetch ranks error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Rank error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
