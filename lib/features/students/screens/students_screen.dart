import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/student_repository.dart';
import '../../dashboard/repositories/dashboard_repository.dart';
import '../../../../models/student_model.dart';
import '../../../../core/utils/validator_service.dart';

// Provides standard fetched students via lazy rendering
final studentsListProvider = FutureProvider.autoDispose<List<StudentModel>>((ref) async {
  return ref.watch(studentRepositoryProvider).getAllStudents(limit: 50, offset: 0);
});

class StudentsScreen extends ConsumerStatefulWidget {
  const StudentsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  void _showAddStudentDialog() {
    final nameController = TextEditingController();
    final rollController = TextEditingController();
    final phoneController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing while saving
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Student'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name'), enabled: !isSaving),
                  TextField(controller: rollController, decoration: const InputDecoration(labelText: 'Roll Number'), enabled: !isSaving),
                  TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Phone'), keyboardType: TextInputType.phone, enabled: !isSaving),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx), 
                  child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      // Pre-DB Validation Bounds checking
                      ValidatorService.validateStudent(nameController.text, rollController.text, phoneController.text);
                      
                      final newStudent = StudentModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text,
                        rollNumber: rollController.text,
                        classId: 'CLASS_10A', // Mocking for now
                        phone: phoneController.text,
                        parentName: 'Pending',
                        parentPhone: 'Pending',
                        dateOfBirth: DateTime.now().subtract(const Duration(days: 5000)),
                        gender: 'Unknown',
                        address: 'Pending',
                        admissionDate: DateTime.now(),
                        deviceId: 'device_01', 
                      );

                      await ref.read(studentRepositoryProvider).addStudent(newStudent);
                      ref.invalidate(studentsListProvider); // Trigger live list reload
                      ref.invalidate(dashboardMetricsProvider); // Trigger dashboard aggregates update (Total Students)
                      
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student added successfully!')));
                      }
                    } catch (error) {
                       setDialogState(() => isSaving = false);
                       if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(error.toString().replaceAll("Exception:", "")),
                            backgroundColor: Colors.redAccent,
                          ));
                       }
                    }
                  },
                  child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
                )
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsListProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.person_add),
      ),
      body: studentsAsync.when(
        data: (students) => students.isEmpty 
            ? const Center(child: Text('No students found.'))
            : ListView.builder(
                itemCount: students.length,
                itemBuilder: (ctx, index) {
                   final s = students[index];
                   return ListTile(
                     leading: CircleAvatar(child: Text(s.name[0])),
                     title: Text(s.name),
                     subtitle: Text('Roll: ${s.rollNumber} | Class: ${s.classId}'),
                     trailing: IconButton(
                       icon: const Icon(Icons.delete_outline, color: Colors.red),
                       onPressed: () async {
                         await ref.read(studentRepositoryProvider).deleteStudentSoft(s.id);
                         ref.invalidate(studentsListProvider);
                       },
                     ),
                   );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
