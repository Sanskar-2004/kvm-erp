import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/timetable_provider.dart';

class TimetableScreen extends ConsumerWidget {
  const TimetableScreen({super.key});

  static const _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timetable = ref.watch(timetableProvider);

    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Timetable'),
          bottom: TabBar(
            isScrollable: true,
            tabs: _days.map((d) => Tab(text: d)).toList(),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
          ),
        ),
        body: TabBarView(
          children: _days.map((day) {
            final periods = timetable
                .where((t) => t.day == day)
                .toList()
              ..sort((a, b) => a.periodNumber.compareTo(b.periodNumber));

            if (periods.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text('No classes on $day',
                        style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: periods.length,
              itemBuilder: (context, index) {
                final period = periods[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('P${period.periodNumber}'),
                    ),
                    title: Text(period.subject),
                    subtitle: Text(
                        '${period.startTime} - ${period.endTime} • ${period.teacherName}'),
                    trailing: const Icon(Icons.chevron_right),
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
