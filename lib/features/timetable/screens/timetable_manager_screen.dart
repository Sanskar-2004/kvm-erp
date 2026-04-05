import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/class_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../staff/repositories/assignment_repository.dart';
import '../../../models/staff_assignment_model.dart';

/// Admin Timetable Manager — Week grid with clash detection
class TimetableManagerScreen extends ConsumerStatefulWidget {
  const TimetableManagerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TimetableManagerScreen> createState() => _TimetableManagerState();
}

class _TimetableManagerState extends ConsumerState<TimetableManagerScreen>
    with SingleTickerProviderStateMixin {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
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

  String _selectedClass = '10';
  List<Map<String, dynamic>> _entries = [];
  List<StaffAssignmentModel> _classAssignments = [];
  bool _isLoading = false;
  late TabController _tabController;

  final _classes = ClassConstants.allClasses;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _loadTimetable();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTimetable() async {
    setState(() => _isLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      final response = await http.get(
        Uri.parse('$BASE_URL/timetable/class/$_selectedClass'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _entries = List<Map<String, dynamic>>.from(data['timetable'] ?? []);
      }

      // Load assigned staff for the dropdown options
      try {
        final assigns = await ref.read(assignmentRepositoryProvider).getAssignmentsByClass(_selectedClass);
        _classAssignments = assigns;
      } catch (_) {
        _classAssignments = [];
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic>? _findEntry(String day, int periodNum) {
    return _entries.cast<Map<String, dynamic>?>().firstWhere(
      (e) => e!['day_of_week'] == day && e['period_number'] == periodNum,
      orElse: () => null,
    );
  }

  Color _colorForSubject(String subject) {
    return _subjectColors[subject] ?? Colors.indigo;
  }

  int get _filledSlots => _entries.length;
  int get _totalSlots => _days.length * _periods.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Manager'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTimetable,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Header: Class selector + Stats ──
          _buildHeader(),

          // ── Grid View ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDayTabs(),
          ),
        ],
      ),
    );
  }

  // ── Header with class selector and fill stats ──
  Widget _buildHeader() {
    final pct = _totalSlots > 0 ? (_filledSlots / _totalSlots * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Class selector chip
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedClass,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
                      dropdownColor: Colors.indigo[600],
                      items: _classes.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('  Class $c', style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
                      )).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v ?? '10');
                        _loadTimetable();
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Stats pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.pie_chart_rounded, size: 16, color: Colors.indigo[400]),
                    const SizedBox(width: 6),
                    Text('$_filledSlots/$_totalSlots', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.indigo[700])),
                    const SizedBox(width: 4),
                    Text('($pct%)', style: TextStyle(fontSize: 11, color: Colors.indigo[300])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Fill progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _totalSlots > 0 ? _filledSlots / _totalSlots : 0,
              minHeight: 4,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                _filledSlots / (_totalSlots > 0 ? _totalSlots : 1) > 0.7 ? Colors.green : Colors.indigo,
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Day Tabs with period cards ──
  Widget _buildDayTabs() {
    return Column(
      children: [
        // Fancy day tabs
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: false,
            indicator: BoxDecoration(
              color: Colors.indigo[600],
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[500],
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            dividerColor: Colors.transparent,
            labelPadding: EdgeInsets.zero,
            tabs: List.generate(_days.length, (i) {
              final dayEntries = _entries.where((e) => e['day_of_week'] == _days[i]).length;
              return Tab(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_dayShort[i]),
                    if (dayEntries > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dayEntries == _periods.length ? Colors.green[300] : Colors.orange[300],
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 6),

        // Period cards
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _days.map((day) => _buildDayPeriods(day)).toList(),
          ),
        ),
      ],
    );
  }

  // ── Period list for a day ──
  Widget _buildDayPeriods(String day) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      itemCount: _periods.length,
      itemBuilder: (context, index) {
        final period = _periods[index];
        final periodNum = period['num'] as int;
        final entry = _findEntry(day, periodNum);
        final isFilled = entry != null;
        final subject = entry?['subject']?.toString() ?? '';
        final teacherName = entry?['teacher_name']?.toString() ?? '';
        final teacherId = entry?['teacher_id']?.toString() ?? '';
        final color = isFilled ? _colorForSubject(subject) : Colors.grey;

        // Break indicator
        final isBreak = periodNum == 3 || periodNum == 5;

        return Column(
          children: [
            if (isBreak)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.free_breakfast_rounded, size: 14, color: Colors.amber[700]),
                    const SizedBox(width: 6),
                    Text(periodNum == 3 ? 'Short Break' : 'Lunch Break',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber[800])),
                  ],
                ),
              ),

            // Period card
            InkWell(
              onTap: isFilled ? () => _showEntryDetail(day, period, entry) : () => _showAddDialog(day, period),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isFilled ? color.withOpacity(0.07) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isFilled ? color.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                    width: isFilled ? 1.5 : 1,
                  ),
                  boxShadow: isFilled ? [
                    BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                  ] : null,
                ),
                child: Row(
                  children: [
                    // Period number + time
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isFilled ? color.withOpacity(0.12) : Colors.grey.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text('P$periodNum', style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15,
                            color: isFilled ? color : Colors.grey[500],
                          )),
                          const SizedBox(height: 2),
                          Text('${period['start']}', style: TextStyle(fontSize: 9, color: Colors.grey[500])),
                          Text('${period['end']}', style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Content
                    Expanded(
                      child: isFilled
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(subject, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.person_rounded, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(teacherName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ]),
                                if (teacherId.isNotEmpty)
                                  Row(children: [
                                    Icon(Icons.badge_rounded, size: 13, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text('ID: $teacherId', style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                                  ]),
                              ],
                            )
                          : Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add_rounded, size: 20, color: Colors.indigo),
                                ),
                                const SizedBox(width: 12),
                                Text('Tap to assign', style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                    ),

                    // Status indicator
                    if (isFilled)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.check_circle_rounded, size: 18, color: color),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Entry detail popup (view existing) ──
  void _showEntryDetail(String day, Map<String, dynamic> period, Map<String, dynamic> entry) {
    final subject = entry['subject']?.toString() ?? '-';
    final teacherName = entry['teacher_name']?.toString() ?? '-';
    final teacherId = entry['teacher_id']?.toString() ?? '-';
    final color = _colorForSubject(subject);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(Icons.book_rounded, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(subject, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text('$day • Period ${period['num']}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
            const SizedBox(height: 20),

            // Info rows
            _detailInfoRow(Icons.schedule_rounded, 'Time', '${period['start']} – ${period['end']}'),
            _detailInfoRow(Icons.class_rounded, 'Class', 'Class $_selectedClass'),
            _detailInfoRow(Icons.person_rounded, 'Teacher', teacherName),
            _detailInfoRow(Icons.badge_rounded, 'Teacher ID', teacherId),
            const SizedBox(height: 16),

            // Action buttons
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddDialog(day, period);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Reassign'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.indigo,
                    side: const BorderSide(color: Colors.indigo),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detailInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 10),
        SizedBox(width: 80, child: Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
      ]),
    );
  }

  // ── Add / Assign Dialog ──
  void _showAddDialog(String day, Map<String, dynamic> period) {
    StaffAssignmentModel? selectedAssignment;
    if (_classAssignments.isNotEmpty) {
      selectedAssignment = _classAssignments.first;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Column(
          children: [
            // Day + period header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.indigo[600]!, Colors.indigo[400]!]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('$day  •  Period ${period['num']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('${period['start']} – ${period['end']}  •  Class $_selectedClass',
                style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  if (_classAssignments.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                      child: const Text('No staff assigned to this class yet. Go to Dashboard > Assign Staff.',
                          style: TextStyle(color: Colors.red)),
                    )
                  else ...[
                    const Text('Select Assigned Staff', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<StaffAssignmentModel>(
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.person_rounded, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      value: selectedAssignment,
                      items: _classAssignments.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text('${a.staffName} — ${a.subject}'),
                        );
                      }).toList(),
                      onChanged: (v) => setDialogState(() => selectedAssignment = v),
                    ),
                  ]
                ],
              ),
            );
          }
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[600],
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _classAssignments.isEmpty || selectedAssignment == null
                    ? null
                    : () => _createEntry(ctx, day, period, selectedAssignment!.subject, selectedAssignment!.staffId, selectedAssignment!.staffName ?? ''),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Assign', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── API call to create entry ──
  Future<void> _createEntry(BuildContext ctx, String day, Map<String, dynamic> period,
      String subject, String teacherId, String teacherName) async {
    if (subject.trim().isEmpty || teacherId.trim().isEmpty || teacherName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All fields are required'),
          backgroundColor: Colors.orange[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    final id = 'tt_${_selectedClass}_${day}_${period['num']}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/timetable'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.token}',
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

      if (ctx.mounted) Navigator.pop(ctx);

      if (response.statusCode == 409) {
        // CLASH DETECTED
        final error = jsonDecode(response.body);
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
              title: const Text('Schedule Clash!', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(
                error['message'] ?? 'Teacher is already booked for another class at this time.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
        }
      } else {
        _loadTimetable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text('$subject assigned to $teacherName ✅'),
              ]),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (ctx.mounted) Navigator.pop(ctx);
      debugPrint('Create error: $e');
    }
  }
}
