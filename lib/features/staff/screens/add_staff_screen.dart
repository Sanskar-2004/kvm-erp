import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/staff_repository.dart';
import '../../../models/staff_model.dart';
import 'package:uuid/uuid.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  const AddStaffScreen({super.key});

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String _name = '';
  String _phone = '';
  String _email = '';
  String _role = 'teacher';
  String _employeeCode = '';
  String _department = '';
  String _joiningDate = DateTime.now().toIso8601String().split('T')[0];
  double _salary = 0.0;
  
  // Dynamic Role Fields
  String _subjectSpecialization = '';
  String _vehicleAssigned = '';
  
  // Auth Linkage
  bool _createLogin = false;
  String _password = '';

  bool _isLoading = false;

  final _roles = [
    'teacher', 'driver', 'peon', 'accountant', 
    'principal', 'librarian', 'security'
  ];

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final staff = StaffModel(
        id: const Uuid().v4(),
        name: _name,
        phone: _phone,
        email: _email.isEmpty ? null : _email,
        role: _role,
        employeeCode: _employeeCode.isEmpty ? null : _employeeCode,
        department: _department.isEmpty ? null : _department,
        joiningDate: _joiningDate,
        salary: _salary,
        subjectSpecialization: _role == 'teacher' ? _subjectSpecialization : null,
        vehicleAssigned: _role == 'driver' ? _vehicleAssigned : null,
        canLogin: _createLogin,
        deviceId: 'device-mobile', // Fallback, could grab real ID
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final repo = ref.read(staffRepositoryProvider);
      
      // If we are spawning a login account, hit the online API. Otherwise, save locally to SQlite (or offline API path)
      // Since it's unified we hit API for now.
      await repo.createStaffWithAuth(
        staff,
        username: _phone.isNotEmpty ? _phone : staff.email, // Use phone as fallback username
        password: _password,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff record created successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Staff'),
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
                  const Text('HR Master Record', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
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
                    decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    onSaved: (v) => _name = v!,
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.isEmpty ? 'Required for login' : null,
                          onSaved: (v) => _phone = v!,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
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
                          decoration: InputDecoration(labelText: 'Employee Code', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          onSaved: (v) => _employeeCode = v ?? '',
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          decoration: InputDecoration(labelText: 'Department', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                          onSaved: (v) => _department = v ?? '',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
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
                      decoration: InputDecoration(labelText: 'Assigned Vehicle/Route', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => _role == 'driver' && v!.isEmpty ? 'Required for drivers' : null,
                      onSaved: (v) => _vehicleAssigned = v!,
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Authentication Section
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey[300]!)
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SwitchListTile(
                          title: const Text('Create Login Account', style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Spawns a linked ERP identity for app access.'),
                          value: _createLogin,
                          onChanged: (v) => setState(() => _createLogin = v),
                        ),
                        if (_createLogin) ...[
                          const SizedBox(height: 16),
                          Text('Username will default to their Phone Number.', style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                          const SizedBox(height: 12),
                          TextFormField(
                            decoration: InputDecoration(labelText: 'Temporary Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.white),
                            validator: (v) => _createLogin && v!.length < 6 ? 'Password must be at least 6 characters' : null,
                            onSaved: (v) => _password = v!,
                          ),
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[600],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submitForm,
                      child: const Text('Save Staff Member', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              )
            ),
        ),
    );
  }
}
