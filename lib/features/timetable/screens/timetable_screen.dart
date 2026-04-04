import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';

class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  List<Map<String, dynamic>> _entries = [];
  bool _isLoading = true;

  static const _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _loadTimetable();
  }

  Future<void> _loadTimetable() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/timetable/teacher/${session.userId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _entries = List<Map<String, dynamic>>.from(data['timetable'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Timetable load error: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getPeriodsForDay(String day) {
    final dayEntries = _entries.where((e) {
      final d = e['day_of_week']?.toString() ?? e['day']?.toString() ?? '';
      return d.toLowerCase() == day.toLowerCase();
    }).toList();
    dayEntries.sort((a, b) =>
        (a['period_number'] as int? ?? 0).compareTo(b['period_number'] as int? ?? 0));
    return dayEntries;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          leading: Navigator.canPop(context)
              ? IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context))
              : null,
          title: const Text('My Timetable'),
          actions: [
            IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadTimetable),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((d) => Tab(text: d)).toList(),
            labelColor: Colors.blue[800],
            unselectedLabelColor: Colors.grey[500],
            indicatorColor: Colors.blue[700],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _entries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy_rounded, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No timetable assigned yet', style: TextStyle(color: Colors.grey[500])),
                        const SizedBox(height: 8),
                        Text('Ask admin to set up your schedule', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      ],
                    ),
                  )
                : TabBarView(
                    children: _days.map((day) {
                      final periods = _getPeriodsForDay(day);

                      if (periods.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.weekend_rounded, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No classes on $day', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: periods.length,
                        itemBuilder: (context, index) {
                          final p = periods[index];
                          final periodNum = p['period_number'] ?? (index + 1);
                          final subject = p['subject']?.toString() ?? 'Unknown';
                          final classId = p['class_id']?.toString() ?? '-';
                          final start = p['start_time']?.toString() ?? '';
                          final end = p['end_time']?.toString() ?? '';

                          final colors = [Colors.blue, Colors.green, Colors.purple, Colors.orange, Colors.teal, Colors.red, Colors.indigo, Colors.pink];
                          final color = colors[index % colors.length];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: color.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                // Period number
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text('P$periodNum',
                                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Subject & class
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(subject, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.class_rounded, size: 14, color: Colors.grey[500]),
                                        const SizedBox(width: 4),
                                        Text('Class $classId', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                      ]),
                                    ],
                                  ),
                                ),
                                // Time
                                if (start.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(start, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                                      Text(end, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
      ),
    );
  }
}
