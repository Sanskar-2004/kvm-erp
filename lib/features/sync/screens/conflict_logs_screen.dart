import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../../../services/sync/sync_service.dart';
import 'package:http/http.dart' as http;
import '../../../../features/auth/repositories/auth_repository.dart';
import '../../../../core/constants/app_constants.dart';
import 'dart:convert';

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
            ),
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.red),
              onPressed: () => _showNukeDialog(context),
            ),
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

  Future<void> _showNukeDialog(BuildContext context) async {
    final TextEditingController passwordController = TextEditingController();
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ NUKE CLOUD DB?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This will instantly delete ALL students, parents, staff, fees, attendance, and marks from the LIVE PostgreSQL server.\n\nEnter Admin Password to confirm:'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('NUKE IT', style: TextStyle(color: Colors.white))
          ),
        ]
      )
    );

    if (confirm == true) {
      final password = passwordController.text;
      if (password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is required!')));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nuking remote database...')));
      try {
        final session = await ref.read(authRepositoryProvider).getSession();
        final response = await http.post(
          Uri.parse('${BASE_URL}/admin/nuke-database'),
          headers: {
            'Authorization': 'Bearer ${session?.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'password': password}),
        );
        
        if (response.statusCode == 200) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('SUCCESS: Remote cloud DB wiped! Please Clear App Data to reset the local database.'),
             duration: Duration(seconds: 5),
           ));
        } else {
           final error = jsonDecode(response.body)['message'] ?? 'Unknown error';
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $error')));
        }
      } catch(e) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
