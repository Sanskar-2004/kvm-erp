import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/class_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../staff/repositories/staff_repository.dart';
import '../../staff/repositories/assignment_repository.dart';
import '../../../models/staff_assignment_model.dart';
import '../../../models/staff_model.dart';
import '../providers/academics_providers.dart';

class AcademicsScreen extends ConsumerStatefulWidget {
  const AcademicsScreen({super.key});

  @override
  ConsumerState<AcademicsScreen> createState() => _AcademicsScreenState();
}

class _AcademicsScreenState extends ConsumerState<AcademicsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _selectedClass = ClassConstants.allClasses.first;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];
  static const _dayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _periods = [
    {'num': 1, 'start': '08:00', 'end': '08:45'},
    {'num': 2, 'start': '08:45', 'end': '09:30'},
    {'num': 3, 'start': '09:45', 'end': '10:30'},
    {'num': 4, 'start': '10:30', 'end': '11:15'},
    {'num': 5, 'start': '11:30', 'end': '12:15'},
    {'num': 6, 'start': '12:15', 'end': '13:00'},
    {'num': 7, 'start': '13:45', 'end': '14:30'},
  ];

  static const _subjectColors = <String, Color>{
    'Mathematics': Color(0xFF5C6BC0),
    'English': Color(0xFF26A69A),
    'Hindi': Color(0xFFEF5350),
    'Science': Color(0xFF66BB6A),
    'Social Studies': Color(0xFFFF7043),
    'Computer Science': Color(0xFF42A5F5),
    'Physical Education': Color(0xFF8D6E63),
    'Art': Color(0xFFEC407A),
  };

  Color _colorForSubject(String subject) {
    for (final key in _subjectColors.keys) {
      if (subject.toLowerCase().contains(key.toLowerCase()))
        return _subjectColors[key]!;
    }
    return Colors.indigo;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshProvider() {
    ref.invalidate(classAssignmentsProvider(_selectedClass));
    ref.invalidate(classTimetableProvider(_selectedClass));
    ref.invalidate(classInsightsProvider(_selectedClass));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Academics Center'),
        backgroundColor: Colors.indigo[800],
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _refreshProvider),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            children: [
              // Header Dropdowns
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: _buildDropdown(
                    'Class', ClassConstants.allClasses, _selectedClass, (v) {
                  setState(() => _selectedClass = v!);
                  _refreshProvider();
                }),
              ),
              Container(
                color: Colors.indigo[800],
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.amber,
                  indicatorWeight: 4,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.indigo[200],
                  tabs: const [
                    Tab(icon: Icon(Icons.assignment_ind), text: 'Assignments'),
                    Tab(icon: Icon(Icons.schedule), text: 'Timetable'),
                    Tab(icon: Icon(Icons.insights), text: 'Insights'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssignmentsTab(),
          _buildTimetableTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonHideUnderline(
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          filled: true,
          fillColor: Colors.grey[50],
        ),
        value: value,
        icon: const Icon(Icons.arrow_drop_down, color: Colors.indigo),
        items: items
            .map((i) => DropdownMenuItem(
                value: i,
                child: Text('Class $i',
                    style: const TextStyle(fontWeight: FontWeight.bold))))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ─── TAB 1: ASSIGNMENTS ───────────────────────────────────────────────

  Widget _buildAssignmentsTab() {
    final assignmentsAsync =
        ref.watch(classAssignmentsProvider(_selectedClass));
    return Column(
      children: [
        Expanded(
          child: assignmentsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (assignments) {
              if (assignments.isEmpty) {
                return const Center(
                    child: Text('No subject assignments for this class yet.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: assignments.length,
                itemBuilder: (context, index) {
                  final a = assignments[index];
                  return Card(
                    elevation: 1,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: Colors.indigo[100],
                          child: Icon(Icons.book, color: Colors.indigo[700])),
                      title: Text(a.subject,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${a.staffName ?? 'Unknown Teacher'}\nMax: ${a.maxPeriodsPerWeek} p/wk'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (a.isClassTeacher)
                            const Chip(
                                label: Text('Class Teacher',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.amber,
                                padding: EdgeInsets.zero),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red),
                            onPressed: () => _deleteAssignment(a.id),
                          ),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Add Subject Assignment',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[600],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _showAddAssignmentModal,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _deleteAssignment(String id) async {
    try {
      await ref.read(assignmentRepositoryProvider).deleteAssignment(id);
      _refreshProvider();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showAddAssignmentModal() async {
    final teachers =
        await ref.read(staffRepositoryProvider).getStaffByRole('teacher');
    if (!mounted) return;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => _AddAssignmentSheet(
              teachers: teachers,
              classId: _selectedClass,
              onAssign: () => _refreshProvider(),
            ));
  }

  // ─── TAB 2: TIMETABLE ──────────────────────────────────────────────────

  Widget _buildTimetableTab() {
    final timetableAsync = ref.watch(classTimetableProvider(_selectedClass));
    final assignmentsAsync =
        ref.watch(classAssignmentsProvider(_selectedClass));

    return timetableAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (entries) {
          return DefaultTabController(
            length: _days.length,
            child: Column(
              children: [
                // Day Tabs
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(14)),
                  child: TabBar(
                    isScrollable: false,
                    indicator: BoxDecoration(
                        color: Colors.indigo[600],
                        borderRadius: BorderRadius.circular(12)),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey[700],
                    labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12),
                    tabs: List.generate(_days.length, (i) {
                      final dayEntries = entries
                          .where((e) => e['day_of_week'] == _days[i])
                          .length;
                      return Tab(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(_dayShort[i]),
                            if (dayEntries > 0)
                              Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.greenAccent)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                // Period List
                Expanded(
                  child: TabBarView(
                    children: _days.map((day) {
                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                        itemCount: _periods.length,
                        itemBuilder: (context, index) {
                          final period = _periods[index];
                          final periodNum = period['num'] as int;
                          final entry = entries
                              .cast<Map<String, dynamic>?>()
                              .firstWhere(
                                  (e) =>
                                      e!['day_of_week'] == day &&
                                      e['period_number'] == periodNum,
                                  orElse: () => null);
                          final isFilled = entry != null;
                          final subject = entry?['subject']?.toString() ?? '';
                          final teacherName =
                              entry?['teacher_name']?.toString() ?? '';
                          final color = isFilled
                              ? _colorForSubject(subject)
                              : Colors.grey;

                          final isBreak = periodNum == 3 || periodNum == 5;
                          return Column(
                            children: [
                              if (isBreak)
                                Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.free_breakfast_rounded,
                                          size: 14, color: Colors.amber[700]),
                                      const SizedBox(width: 6),
                                      Text(
                                          periodNum == 3
                                              ? 'Short Break'
                                              : 'Lunch Break',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.amber[800])),
                                    ],
                                  ),
                                ),
                              InkWell(
                                onTap: () {
                                  if (!isFilled &&
                                      assignmentsAsync.value != null) {
                                    _showPeriodAssignDialog(
                                        day, period, assignmentsAsync.value!);
                                  } else if (isFilled) {
                                    _deleteTimetableEntry(entry!['id']);
                                  }
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isFilled
                                        ? color.withOpacity(0.07)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: isFilled
                                            ? color.withOpacity(0.2)
                                            : Colors.grey.withOpacity(0.15),
                                        width: isFilled ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 52,
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        decoration: BoxDecoration(
                                            color: isFilled
                                                ? color.withOpacity(0.12)
                                                : Colors.grey.withOpacity(0.08),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: Column(
                                          children: [
                                            Text('P$periodNum',
                                                style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: isFilled
                                                        ? color
                                                        : Colors.grey[500])),
                                            const SizedBox(height: 2),
                                            Text('${period['start']}',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey[500])),
                                            Text('${period['end']}',
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    color: Colors.grey[400])),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: isFilled
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                    Text(subject,
                                                        style: TextStyle(
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            color: color)),
                                                    const SizedBox(height: 4),
                                                    Row(children: [
                                                      Icon(Icons.person,
                                                          size: 14,
                                                          color:
                                                              Colors.grey[500]),
                                                      const SizedBox(width: 4),
                                                      Text(teacherName,
                                                          style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .grey[600]))
                                                    ]),
                                                  ])
                                            : Row(children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: Colors.indigo
                                                            .withOpacity(0.08),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(10)),
                                                    child: const Icon(Icons.add,
                                                        size: 20,
                                                        color: Colors.indigo)),
                                                const SizedBox(width: 12),
                                                Text('Tap to slot',
                                                    style: TextStyle(
                                                        color: Colors.grey[500],
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w500)),
                                              ]),
                                      ),
                                      if (isFilled)
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_circle_outline,
                                              color: Colors.red),
                                          onPressed: () =>
                                              _deleteTimetableEntry(
                                                  entry!['id']),
                                        )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        });
  }

  void _showPeriodAssignDialog(String day, Map<String, dynamic> period,
      List<StaffAssignmentModel> availableAssignments) {
    if (availableAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No Subject Assignments exist for this class yet! Use the Assignments Tab first.')));
      return;
    }

    StaffAssignmentModel? selectedAssign = availableAssignments.first;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, setDialogState) => AlertDialog(
                title: Text('Slot Period ${period['num']} ($day)'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                        'Select predefined subject & teacher combination:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<StaffAssignmentModel>(
                      decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Subject / Teacher'),
                      value: selectedAssign,
                      isExpanded: true,
                      items: availableAssignments
                          .map((a) => DropdownMenuItem(
                                value: a,
                                child: Text('${a.subject} (${a.staffName})',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedAssign = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      if (selectedAssign != null) {
                        Navigator.pop(ctx);
                        await _createTimetableEntry(
                            day,
                            period,
                            selectedAssign!.subject,
                            selectedAssign!.staffId,
                            selectedAssign!.staffName ?? '');
                      }
                    },
                    child: const Text('Slot In'),
                  )
                ],
              ),
            ));
  }

  Future<void> _createTimetableEntry(String day, Map<String, dynamic> period,
      String subject, String teacherId, String teacherName) async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;
    final id =
        'tt_${_selectedClass}_${day}_${period['num']}_${DateTime.now().millisecondsSinceEpoch}';
    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/timetable'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}'
        },
        body: jsonEncode({
          'id': id,
          'class_id': _selectedClass,
          'subject': subject,
          'teacher_id': teacherId,
          'teacher_name': teacherName,
          'day_of_week': day,
          'start_time': period['start'],
          'end_time': period['end'],
          'period_number': period['num'],
        }),
      );
      if (response.statusCode == 409) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('⚠️ Schedule Clash! Teacher already booked at this time!'),
            backgroundColor: Colors.red));
      } else {
        _refreshProvider();
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<void> _deleteTimetableEntry(String id) async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;
    try {
      await http.delete(
        Uri.parse('$BASE_URL/timetable/$id'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );
      _refreshProvider();
    } catch (e) {
      debugPrint('Delete Error: $e');
    }
  }

  // ─── TAB 3: INSIGHTS ──────────────────────────────────────────────────

  Widget _buildInsightsTab() {
    final insightsAsync = ref.watch(classInsightsProvider(_selectedClass));
    return insightsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (insights) {
          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              color: Colors.blue[50],
              child: ListTile(
                leading: const Icon(Icons.analytics, color: Colors.blue),
                title: const Text('Academic Coverage',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text(
                    '${(insights['coverage_percent'] * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: LinearProgressIndicator(
                    value: insights['coverage_percent']),
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                    insights['has_class_teacher']
                        ? Icons.admin_panel_settings
                        : Icons.warning_amber,
                    color: insights['has_class_teacher']
                        ? Colors.green
                        : Colors.red),
                title: Text(
                    insights['has_class_teacher']
                        ? 'Class Teacher Assigned'
                        : 'No Class Teacher',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('Total Scheduled Periods',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('${insights['total_scheduled_periods']}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            if ((insights['overloaded_staff'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('⚠️ Overloaded Staff Warnings',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const SizedBox(height: 8),
              ...(insights['overloaded_staff'] as List).map((s) => Card(
                    color: Colors.red[50],
                    child: ListTile(
                      leading: const Icon(Icons.error, color: Colors.red),
                      title: Text(s['teacher_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Subject: ${s['subject']}'),
                      trailing: Text(
                          '${s['assigned']} / ${s['max']} max periods',
                          style: const TextStyle(
                              color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                  )),
            ]
          ]);
        });
  }
}

class _AddAssignmentSheet extends StatefulWidget {
  final List<StaffModel> teachers;
  final String classId;
  final VoidCallback onAssign;

  const _AddAssignmentSheet(
      {required this.teachers, required this.classId, required this.onAssign});

  @override
  State<_AddAssignmentSheet> createState() => _AddAssignmentSheetState();
}

class _AddAssignmentSheetState extends State<_AddAssignmentSheet> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStaffId;
  String _subject = '';
  int _maxDay = 6;
  int _maxWeek = 30;
  bool _isClassTeacher = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Subject Assignment',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo)),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                  labelText: 'Teacher',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              value: _selectedStaffId,
              items: widget.teachers
                  .map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text('${s.name} (${s.employeeCode ?? 'N/A'})')))
                  .toList(),
              onChanged: (v) => setState(() => _selectedStaffId = v),
              validator: (v) => v == null ? 'Select teacher' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                  labelText: 'Subject (e.g. Mathematics)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12))),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              onSaved: (v) => _subject = v!,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '6',
                    decoration: InputDecoration(
                        labelText: 'Max / Day',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => _maxDay = int.tryParse(v ?? '6') ?? 6,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: '30',
                    decoration: InputDecoration(
                        labelText: 'Max / Week',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12))),
                    keyboardType: TextInputType.number,
                    onSaved: (v) => _maxWeek = int.tryParse(v ?? '30') ?? 30,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Is Class Teacher?',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              value: _isClassTeacher,
              onChanged: (v) => setState(() => _isClassTeacher = v),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[600],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Save Assignment',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate() ||
                        _selectedStaffId == null) return;
                    _formKey.currentState!.save();
                    try {
                      final assign = StaffAssignmentModel(
                          id: const Uuid().v4(),
                          staffId: _selectedStaffId!,
                          classId: widget.classId,
                          subject: _subject,
                          maxPeriodsPerDay: _maxDay,
                          maxPeriodsPerWeek: _maxWeek,
                          isClassTeacher: _isClassTeacher,
                          deviceId: 'mobile',
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now());
                      await ref
                          .read(assignmentRepositoryProvider)
                          .createAssignment(assign);
                      if (mounted) Navigator.pop(context);
                      widget.onAssign();
                    } catch (e) {
                      debugPrint(e.toString());
                    }
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
