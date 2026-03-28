import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../../../services/sync/sync_service.dart';

class ConflictLogsScreen extends ConsumerStatefulWidget {
  const ConflictLogsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ConflictLogsScreen> createState() => _ConflictLogsScreenState();
}

class _ConflictLogsScreenState extends ConsumerState<ConflictLogsScreen> {
  final SQLiteService _dbService = SQLiteService();
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _failed = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final db = await _dbService.database;
    final logResults = await db.query('sync_conflicts', orderBy: 'created_at DESC', limit: 100);
    final failResults = await db.query('sync_queue', where: 'synced = ?', whereArgs: [toDb(SyncStatus.failed)]);
    
    setState(() {
      _logs = logResults;
      _failed = failResults;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('System Audit & Dead Queues'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() => _isLoading = true);
                _fetchData();
              },
            )
          ],
          bottom: const TabBar(
            tabs: [
               Tab(text: "Sync Conflicts"),
               Tab(text: "Failed Queues"),
            ]
          ),
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                   // Tab 1: Conflicts
                   _logs.isEmpty 
                      ? const Center(child: Text('No sync conflicts recorded.'))
                      : ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ExpansionTile(
                                leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                                title: Text('Table: ${log['table_name']} | ID: ${log['record_id']}'),
                                subtitle: Text('Res: ${log['resolution_strategy']}'),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text('Time: ${log['created_at']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                   // Tab 2: Failed Queues (Dead)
                   _failed.isEmpty
                      ? const Center(child: Text('No dead queues actively trapped.'))
                      : Column(
                          children: [
                             Padding(
                               padding: const EdgeInsets.all(8.0),
                               child: ElevatedButton.icon(
                                 icon: const Icon(Icons.restore),
                                 label: const Text('Resurrect Failed Queues'),
                                 onPressed: () async {
                                    await ref.read(syncServiceProvider).retryFailedQueue();
                                    _fetchData();
                                 },
                               ),
                             ),
                             Expanded(
                               child: ListView.builder(
                                  itemCount: _failed.length,
                                  itemBuilder: (context, index) {
                                    final fail = _failed[index];
                                    return ListTile(
                                       leading: const Icon(Icons.error, color: Colors.red),
                                       title: Text('Data: ${fail['table_name']} | ID ${fail['record_id']}'),
                                       subtitle: Text('Last Error: ${fail['last_error']}'),
                                    );
                                  }
                               )
                             )
                          ],
                      )
                ]
            )
      ),
    );
  }
}
