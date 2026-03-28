import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../../../services/backup/backup_service.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _jsonInputController = TextEditingController();

  void _showImportWarning() {
    if (_jsonInputController.text.isEmpty) return;

    try {
      final data = jsonDecode(_jsonInputController.text);
      final int studentsCount = data['students']?.length ?? 0;
      final int attendanceCount = data['attendance']?.length ?? 0;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('⚠️ Critical System Import', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               const Text('You are about to modify the offline system architecture directly. The incoming JSON contains:'),
               const SizedBox(height: 12),
               Text('• $studentsCount Students', style: const TextStyle(fontWeight: FontWeight.bold)),
               Text('• $attendanceCount Attendance Logs', style: const TextStyle(fontWeight: FontWeight.bold)),
               const SizedBox(height: 12),
               const Text('The system will SAFELY MERGE this data. Incoming records with older timestamps will be automatically ignored to protect actively tracked data.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
               style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
               onPressed: () async {
                 Navigator.pop(ctx);
                 await ref.read(backupServiceProvider).importDatabase(_jsonInputController.text);
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database Merged Successfully!'), backgroundColor: Colors.green)
                    );
                 }
               },
               child: const Text('Merge Database', style: TextStyle(color: Colors.white)),
            )
          ],
        )
      );
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid JSON format provided.'), backgroundColor: Colors.red)
       );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('System Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export Local Database (Rescue Protocol)'),
              onPressed: () async {
                 final path = await ref.read(backupServiceProvider).exportDatabase();
                 if (context.mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     SnackBar(content: Text('Exported safely to OS Documents: $path'))
                   );
                 }
              },
            ),
            const Divider(height: 48),
            const Text('Import Missing Database', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _jsonInputController,
              maxLines: 6,
              decoration: const InputDecoration(
                hintText: 'Paste KVM ERP JSON payload here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _showImportWarning,
              child: const Text('Validate & Merge Import'),
            )
          ],
        ),
      ),
    );
  }
}
