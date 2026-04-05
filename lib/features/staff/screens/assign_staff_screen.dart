import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/staff_model.dart';
import '../../../models/staff_assignment_model.dart';
import '../repositories/staff_repository.dart';
import '../repositories/assignment_repository.dart';
import '../../../core/constants/class_constants.dart';
import 'package:uuid/uuid.dart';

class AssignStaffScreen extends ConsumerStatefulWidget {
  const AssignStaffScreen({super.key});

  @override
  ConsumerState<AssignStaffScreen> createState() => _AssignStaffScreenState();
}

class _AssignStaffScreenState extends ConsumerState<AssignStaffScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedStaffId;
  String _selectedClass = ClassConstants.allClasses.first;
  String _subject = '';
  int _maxDay = 6;
  int _maxWeek = 30;
  bool _isClassTeacher = false;
  bool _isLoading = false;

  List<StaffModel> _staffList = [];
  List<StaffAssignmentModel> _currentAssignments = [];

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    // Only fetch teachers for assignments usually, but we could fetch all
    final teachers = await ref.read(staffRepositoryProvider).getStaffByRole('teacher');
    setState(() {
      _staffList = teachers;
      if (teachers.isNotEmpty) {
        _selectedStaffId = teachers.first.id;
      }
    });
    _loadAssignmentsForClass();
  }

  Future<void> _loadAssignmentsForClass() async {
    setState(() => _isLoading = true);
    final assignments = await ref.read(assignmentRepositoryProvider).getAssignmentsByClass(_selectedClass);
    if (mounted) setState(() {
      _currentAssignments = assignments;
      _isLoading = false;
    });
  }

  Future<void> _assign() async {
    if (!_formKey.currentState!.validate() || _selectedStaffId == null) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);
    try {
      final assign = StaffAssignmentModel(
        id: const Uuid().v4(),
        staffId: _selectedStaffId!,
        classId: _selectedClass,
        subject: _subject,
        maxPeriodsPerDay: _maxDay,
        maxPeriodsPerWeek: _maxWeek,
        isClassTeacher: _isClassTeacher,
        deviceId: 'device-mobile',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now()
      );

      await ref.read(assignmentRepositoryProvider).createAssignment(assign);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Assigned successfully'), backgroundColor: Colors.green));
        _formKey.currentState!.reset();
        _subject = '';
        _isClassTeacher = false;
        _loadAssignmentsForClass();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await ref.read(assignmentRepositoryProvider).deleteAssignment(id);
      _loadAssignmentsForClass();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Class Assignments'), backgroundColor: Colors.indigo[800]),
      body: Row(
        children: [
          // LEFT PANEL: Form
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Assign Teacher to Class', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 20),

                    // Staff Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Teacher', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: _selectedStaffId,
                      items: _staffList.map((s) => DropdownMenuItem(value: s.id, child: Text('${s.name} (${s.employeeCode ?? 'N/A'})'))).toList(),
                      onChanged: (v) => setState(() => _selectedStaffId = v),
                      validator: (v) => v == null ? 'Select teacher' : null,
                    ),
                    const SizedBox(height: 16),

                    // Class Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(labelText: 'Class', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      value: _selectedClass,
                      items: ClassConstants.allClasses.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        setState(() => _selectedClass = v!);
                        _loadAssignmentsForClass();
                      },
                    ),
                    const SizedBox(height: 16),

                    // Subject Input
                    TextFormField(
                      decoration: InputDecoration(labelText: 'Subject (e.g. Mathematics)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (v) => _subject = v!,
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: '6',
                            decoration: InputDecoration(labelText: 'Max / Day', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            keyboardType: TextInputType.number,
                            onSaved: (v) => _maxDay = int.tryParse(v ?? '6') ?? 6,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: '30',
                            decoration: InputDecoration(labelText: 'Max / Week', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            keyboardType: TextInputType.number,
                            onSaved: (v) => _maxWeek = int.tryParse(v ?? '30') ?? 30,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    SwitchListTile(
                      title: const Text('Is Class Teacher?', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Grants full attendance rights for this class'),
                      value: _isClassTeacher,
                      onChanged: (bool value) => setState(() => _isClassTeacher = value),
                    ),
                    
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _assign,
                        child: const Text('Assign Teacher', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          
          // RIGHT PANEL: Existing lists
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current Assignments for Class $_selectedClass', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_isLoading) const Center(child: CircularProgressIndicator())
                  else if (_currentAssignments.isEmpty) Expanded(child: Center(child: Text('No assignments yet', style: TextStyle(color: Colors.grey[500]))))
                  else Expanded(
                    child: ListView.builder(
                      itemCount: _currentAssignments.length,
                      itemBuilder: (ctx, i) {
                        final a = _currentAssignments[i];
                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: CircleAvatar(backgroundColor: Colors.indigo[100], child: Icon(Icons.book, color: Colors.indigo[700])),
                            title: Text(a.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${a.staffName ?? 'Unknown Teacher'} ${a.isClassTeacher ? '(Class Teacher)' : ''}'),
                            trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _delete(a.id)),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
