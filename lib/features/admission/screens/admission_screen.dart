import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../models/student_model.dart';
import '../../students/screens/student_detail_screen.dart';
import '../../students/screens/students_screen.dart';
import '../../dashboard/repositories/dashboard_repository.dart';

/// Fetches pending students from LOCAL SQLite database
final pendingAdmissionsProvider = FutureProvider.autoDispose<List<StudentModel>>((ref) async {
  try {
    final db = await SQLiteService().database;
    final rows = await db.query(
      'students',
      where: 'status = ? AND is_deleted = 0',
      whereArgs: ['pending'],
      orderBy: 'admission_date DESC',
    );
    return rows.map((r) => StudentModel.fromJson(r)).toList();
  } catch (e) {
    return [];
  }
});

class AdmissionScreen extends ConsumerWidget {
  const AdmissionScreen({Key? key}) : super(key: key);

  Future<void> _updateStatus(String studentId, String status, WidgetRef ref, BuildContext context) async {
    try {
      final db = await SQLiteService().database;
      await db.update(
        'students',
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [studentId],
      );

      // Queue sync
      SQLiteService.onSyncQueued.add(null);

      ref.invalidate(pendingAdmissionsProvider);
      ref.invalidate(studentsListProvider);
      ref.invalidate(dashboardMetricsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Student Approved ✅' : 'Student Rejected ❌'),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingAdmissionsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
        title: const Text('Admission Approvals'),
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
                      style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('All admission requests are processed',
                      style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Count banner
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pending_actions_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Text('${students.length} Pending Approval${students.length > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.orange, fontSize: 14)),
                  ],
                ),
              ),

              // List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: students.length,
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.orange.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Student info
                          InkWell(
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student))),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.orange.withOpacity(0.15),
                                  child: Text(
                                    student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(student.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Roll: ${student.rollNumber} • Class ${student.classId} • ${student.gender}',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                                      ),
                                      if (student.parentName.isNotEmpty)
                                        Text('Parent: ${student.parentName}',
                                            style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('PENDING',
                                      style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Action buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _updateStatus(student.id, 'rejected', ref, context),
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  label: const Text('Reject', style: TextStyle(color: Colors.red)),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Colors.red),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => _updateStatus(student.id, 'approved', ref, context),
                                  icon: const Icon(Icons.check, size: 18),
                                  label: const Text('Approve'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
