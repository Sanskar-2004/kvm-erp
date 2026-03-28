import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';

/// Fetches pending admissions from the backend
final pendingAdmissionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = await ref.read(authRepositoryProvider).getSession();
  if (session == null) return [];

  final response = await http.get(
    Uri.parse('$BASE_URL/students/pending'),
    headers: {'Authorization': 'Bearer ${session.token}'},
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return List<Map<String, dynamic>>.from(data['students']);
  }
  return [];
});

class AdmissionScreen extends ConsumerWidget {
  const AdmissionScreen({Key? key}) : super(key: key);

  Future<void> _updateStatus(String studentId, String status, WidgetRef ref, BuildContext context) async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    final response = await http.patch(
      Uri.parse('$BASE_URL/students/$studentId/status'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({'status': status}),
    );

    if (response.statusCode == 200) {
      ref.invalidate(pendingAdmissionsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Student ${status == 'approved' ? 'Approved ✅' : 'Rejected ❌'}'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admission Approvals'),
        centerTitle: false,
      ),
      body: pendingAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 72, color: Colors.green[300]),
                  const SizedBox(height: 16),
                  Text('No Pending Admissions',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text('All admission requests are processed',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.orange.withOpacity(0.15),
                          child: Text(
                            (student['name'] ?? 'S')[0].toUpperCase(),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, color: Colors.orange),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(student['name'] ?? 'Unknown',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              const SizedBox(height: 2),
                              Text(
                                'Roll: ${student['roll_number'] ?? '-'} • Class: ${student['class_id'] ?? '-'}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: const Text('PENDING',
                              style: TextStyle(color: Colors.orange, fontSize: 10)),
                          backgroundColor: Colors.orange.withOpacity(0.1),
                          side: BorderSide.none,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _updateStatus(student['id'], 'rejected', ref, context),
                            icon: const Icon(Icons.close, color: Colors.red, size: 18),
                            label: const Text('Reject',
                                style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () =>
                                _updateStatus(student['id'], 'approved', ref, context),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
