import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';
import '../../../models/staff_model.dart';
import 'add_staff_screen.dart';
import '../../auth/repositories/auth_repository.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _selectedRole = 'all';
  String _userRole = '';

  final _roles = [
    'all', 'teacher', 'driver', 'peon', 'accountant', 
    'principal', 'librarian', 'security'
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session != null && mounted) {
      setState(() => _userRole = session.role);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Directory'),
        backgroundColor: Colors.indigo[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddStaffScreen()),
              );
              if (result == true) {
                setState(() {}); // refresh
              }
            },
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _roles.map((role) {
                  final isSelected = _selectedRole == role;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      selected: isSelected,
                      label: Text(role.toUpperCase(), style: TextStyle(
                        color: isSelected ? Colors.white : Colors.indigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      )),
                      selectedColor: Colors.indigo[600],
                      checkmarkColor: Colors.white,
                      onSelected: (val) {
                        setState(() => _selectedRole = role);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<StaffModel>>(
              future: _selectedRole == 'all' 
                  ? ref.read(staffRepositoryProvider).getAllStaff()
                  : ref.read(staffRepositoryProvider).getStaffByRole(_selectedRole),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final staff = snapshot.data ?? [];
                if (staff.isEmpty) {
                  return Center(
                    child: Text('No staff found for role: $_selectedRole', 
                      style: TextStyle(color: Colors.grey[600]))
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: staff.length,
                  itemBuilder: (context, index) {
                    final member = staff[index];
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: member.canLogin ? Colors.green[100] : Colors.grey[200],
                          child: Icon(
                            Icons.person, 
                            color: member.canLogin ? Colors.green[700] : Colors.grey[600]
                          ),
                        ),
                        title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${member.role.toUpperCase()} ${member.department != null ? '• ${member.department}' : ''}\n${member.phone ?? 'No Phone'}'),
                        isThreeLine: true,
                        trailing: _userRole == 'admin'
                            ? PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 20),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                onSelected: (action) {
                                  if (action == 'edit') _editStaff(member);
                                  if (action == 'delete') _confirmDeleteStaff(member);
                                },
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_rounded, size: 18, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : member.canLogin 
                                ? const Icon(Icons.key_rounded, color: Colors.amber, size: 20)
                                : const SizedBox.shrink(),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo[600],
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddStaffScreen()),
          );
          if (result == true) {
            setState(() {});
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Staff'),
      ),
    );
  }

  void _editStaff(StaffModel member) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditStaffScreen(staff: member)),
    );
    if (result == true) {
      setState(() {});
    }
  }

  void _confirmDeleteStaff(StaffModel member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Staff?'),
        content: Text('Are you sure you want to remove ${member.name}?\nThis action will soft-delete the record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      try {
        await ref.read(staffRepositoryProvider).deleteStaffLocally(member.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${member.name} removed successfully'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ));
          setState(() {}); // refresh
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red[700],
          ));
        }
      }
    }
  }
}

/// Inline Edit Staff screen — pre-fills existing staff data and updates locally
class EditStaffScreen extends ConsumerStatefulWidget {
  final StaffModel staff;
  const EditStaffScreen({super.key, required this.staff});

  @override
  ConsumerState<EditStaffScreen> createState() => _EditStaffScreenState();
}

class _EditStaffScreenState extends ConsumerState<EditStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late String _name;
  late String _phone;
  late String _email;
  late String _role;
  late String _employeeCode;
  late String _department;
  late double _salary;
  late String _subjectSpecialization;
  late String _vehicleAssigned;

  final _roles = [
    'teacher', 'driver', 'peon', 'accountant', 
    'principal', 'librarian', 'security'
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.staff;
    _name = s.name;
    _phone = s.phone ?? '';
    _email = s.email ?? '';
    _role = s.role;
    _employeeCode = s.employeeCode ?? '';
    _department = s.department ?? '';
    _salary = s.salary;
    _subjectSpecialization = s.subjectSpecialization ?? '';
    _vehicleAssigned = s.vehicleAssigned ?? '';
  }

  Future<void> _updateStaff() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final updated = widget.staff.copyWith(
        name: _name,
        phone: _phone,
        email: _email.isEmpty ? null : _email,
        role: _role,
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
        department: _department.isEmpty ? null : _department,
        salary: _salary,
        subjectSpecialization: _role == 'teacher' ? _subjectSpecialization : null,
        vehicleAssigned: _role == 'driver' ? _vehicleAssigned : null,
        updatedAt: DateTime.now(),
        isSynced: false,
      );

      await ref.read(staffRepositoryProvider).updateStaffLocally(updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Staff updated successfully! ✅'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Staff'),
        elevation: 0,
        backgroundColor: Colors.indigo[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Update Staff Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                    const SizedBox(height: 16),

                    // Role Selection
                    DropdownButtonFormField<String>(
                      value: _role,
                      decoration: InputDecoration(
                         labelText: 'Role Profile',
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                         prefixIcon: const Icon(Icons.badge_rounded),
                      ),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r.toUpperCase()))).toList(),
                      onChanged: (v) => setState(() => _role = v!),
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      initialValue: _name,
                      decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      onSaved: (v) => _name = v!,
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _phone,
                            decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            keyboardType: TextInputType.phone,
                            validator: (v) => v!.isEmpty ? 'Required' : null,
                            onSaved: (v) => _phone = v!,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _email,
                            decoration: InputDecoration(labelText: 'Email (Optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            keyboardType: TextInputType.emailAddress,
                            onSaved: (v) => _email = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _employeeCode,
                            decoration: InputDecoration(labelText: 'Employee Code', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            onSaved: (v) => _employeeCode = v ?? '',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: _department,
                            decoration: InputDecoration(labelText: 'Department', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            onSaved: (v) => _department = v ?? '',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      initialValue: _salary > 0 ? _salary.toStringAsFixed(0) : '',
                      decoration: InputDecoration(labelText: 'Monthly Salary', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _salary = double.tryParse(v ?? '') ?? 0.0,
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Fields
                    if (_role == 'teacher') ...[
                      const Text('Teacher Specifics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _subjectSpecialization,
                        decoration: InputDecoration(labelText: 'Subject Specialization', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => _role == 'teacher' && v!.isEmpty ? 'Required for teachers' : null,
                        onSaved: (v) => _subjectSpecialization = v!,
                      ),
                      const SizedBox(height: 24),
                    ],

                    if (_role == 'driver') ...[
                      const Text('Transport Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 12),
                      TextFormField(
                        initialValue: _vehicleAssigned,
                        decoration: InputDecoration(labelText: 'Assigned Vehicle/Route', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => _role == 'driver' && v!.isEmpty ? 'Required for drivers' : null,
                        onSaved: (v) => _vehicleAssigned = v!,
                      ),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[600],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _updateStaff,
                        child: const Text('Update Staff Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
          ),
    );
  }
}
