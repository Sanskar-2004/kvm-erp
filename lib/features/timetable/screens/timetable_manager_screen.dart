import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';

/// Admin Timetable Manager — Week grid with clash detection
class TimetableManagerScreen extends ConsumerStatefulWidget {
  const TimetableManagerScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TimetableManagerScreen> createState() => _TimetableManagerState();
}

class _TimetableManagerState extends ConsumerState<TimetableManagerScreen> {
  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  static const _periods = [
    {'num': 1, 'start': '08:00', 'end': '08:45'},
    {'num': 2, 'start': '08:45', 'end': '09:30'},
    {'num': 3, 'start': '09:45', 'end': '10:30'},
    {'num': 4, 'start': '10:30', 'end': '11:15'},
    {'num': 5, 'start': '11:30', 'end': '12:15'},
    {'num': 6, 'start': '12:15', 'end': '13:00'},
    {'num': 7, 'start': '13:45', 'end': '14:30'},
  ];

  String _selectedClass = '10';
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = false;

  final _classes = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
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
        setState(() => _entries = List<Map<String, dynamic>>.from(data['timetable'] ?? []));
      }
    } catch (e) {
      debugPrint('Timetable load error: $e');
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

  void _showAddDialog(String day, Map<String, dynamic> period) {
    final subjectCtrl = TextEditingController();
    final teacherIdCtrl = TextEditingController();
    final teacherNameCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_circle_rounded, color: Colors.indigo, size: 22),
            const SizedBox(width: 8),
            Text('$day P${period['num']}', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${period['start']} – ${period['end']}',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            const SizedBox(height: 16),
            TextField(
              controller: subjectCtrl,
              decoration: InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teacherIdCtrl,
              decoration: InputDecoration(
                labelText: 'Teacher ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: teacherNameCtrl,
              decoration: InputDecoration(
                labelText: 'Teacher Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => _createEntry(ctx, day, period, subjectCtrl.text, teacherIdCtrl.text, teacherNameCtrl.text),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Assign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createEntry(BuildContext ctx, String day, Map<String, dynamic> period,
      String subject, String teacherId, String teacherName) async {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(error['message'] ?? 'Teacher is already booked!')),
              ]),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        _loadTimetable();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Timetable entry created ✅'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timetable Manager'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTimetable),
        ],
      ),
      body: Column(
        children: [
          // Class Selector
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.withOpacity(0.15)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedClass,
                isExpanded: true,
                icon: const Icon(Icons.filter_list_rounded, color: Colors.indigo),
                items: _classes.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text('Class $c', style: const TextStyle(fontWeight: FontWeight.w500)),
                )).toList(),
                onChanged: (v) {
                  setState(() => _selectedClass = v ?? '10');
                  _loadTimetable();
                },
              ),
            ),
          ),

          // Week Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(Colors.indigo.withOpacity(0.06)),
                      columnSpacing: 8,
                      columns: [
                        const DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        ..._days.map((d) => DataColumn(
                          label: Text(d.substring(0, 3), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                        )),
                      ],
                      rows: _periods.map((period) {
                        return DataRow(cells: [
                          DataCell(Text('${period['start']}\n${period['end']}',
                              style: const TextStyle(fontSize: 10, height: 1.3))),
                          ..._days.map((day) {
                            final entry = _findEntry(day, period['num'] as int);
                            if (entry != null) {
                              return DataCell(
                                Container(
                                  width: 70,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.indigo.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(entry['subject']?.toString() ?? '',
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis),
                                      Text(entry['teacher_name']?.toString() ?? '',
                                          style: TextStyle(fontSize: 8, color: Colors.grey[600]),
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              );
                            } else {
                              return DataCell(
                                InkWell(
                                  onTap: () => _showAddDialog(day, period),
                                  child: Container(
                                    width: 70,
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.withOpacity(0.2), style: BorderStyle.solid),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, size: 16, color: Colors.grey),
                                  ),
                                ),
                              );
                            }
                          }),
                        ]);
                      }).toList(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
