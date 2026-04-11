import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../repositories/student_repository.dart';
import '../../../core/constants/class_constants.dart';
import '../../../core/constants/app_constants.dart';
import '../../../../models/student_model.dart';
import '../../../../core/utils/validator_service.dart';
import '../../auth/repositories/auth_repository.dart';

class AddStudentScreen extends ConsumerStatefulWidget {
  const AddStudentScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends ConsumerState<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  int _currentStep = 0;

  // Personal
  final _nameCtrl = TextEditingController();
  final _rollCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  String _gender = 'Male';
  String _classId = '10';
  String _bloodGroup = '';
  DateTime _dob = DateTime(2010, 1, 1);
  String _category = 'General';
  String _caste = '';
  String _religion = 'Hindu';
  String _nationality = 'Indian';

  // Address
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController(text: 'Madhya Pradesh');
  final _pincodeCtrl = TextEditingController();

  // Parents
  final _fatherNameCtrl = TextEditingController();
  final _fatherPhoneCtrl = TextEditingController();
  final _fatherOccCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherPhoneCtrl = TextEditingController();

  // Previous Education
  final _prevSchoolCtrl = TextEditingController();
  final _prevClassCtrl = TextEditingController();

  // Login Credentials (Step 5)
  final _studentUsernameCtrl = TextEditingController();
  final _parentUsernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _createAccounts = true;

  static final _classes = ClassConstants.allClasses;
  static const _genders = ['Male', 'Female', 'Other'];
  static const _categories = ['General', 'OBC', 'SC', 'ST', 'EWS'];
  static const _religions = ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Buddhist', 'Jain', 'Other'];
  static const _bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

  @override
  void initState() {
    super.initState();
    // Auto-fill credentials when roll number changes
    _rollCtrl.addListener(_updateDefaultCredentials);
  }

  void _updateDefaultCredentials() {
    final roll = _rollCtrl.text.trim();
    if (roll.isNotEmpty) {
      _studentUsernameCtrl.text = roll;
      _parentUsernameCtrl.text = 'p_$roll';
    }
  }

  @override
  void dispose() {
    _rollCtrl.removeListener(_updateDefaultCredentials);
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate passwords if account creation is enabled
    if (_createAccounts) {
      if (_passwordCtrl.text.length < 6) {
        _showError('Password must be at least 6 characters.');
        return;
      }
      if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
        _showError('Passwords do not match.');
        return;
      }
      if (_studentUsernameCtrl.text.trim().isEmpty || _parentUsernameCtrl.text.trim().isEmpty) {
        _showError('Please enter both student and parent usernames.');
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      ValidatorService.validateStudent(_nameCtrl.text, _rollCtrl.text, _phoneCtrl.text);

      final studentId = DateTime.now().millisecondsSinceEpoch.toString();

      final newStudent = StudentModel(
        id: studentId,
        name: _nameCtrl.text.trim(),
        rollNumber: _rollCtrl.text.trim(),
        classId: _classId,
        email: _emailCtrl.text.trim().isNotEmpty ? _emailCtrl.text.trim() : null,
        phone: _phoneCtrl.text.trim(),
        parentName: _fatherNameCtrl.text.trim(),
        parentPhone: _fatherPhoneCtrl.text.trim().isNotEmpty ? _fatherPhoneCtrl.text.trim() : 'N/A',
        parentOccupation: _fatherOccCtrl.text.trim().isNotEmpty ? _fatherOccCtrl.text.trim() : null,
        motherName: _motherNameCtrl.text.trim().isNotEmpty ? _motherNameCtrl.text.trim() : null,
        motherPhone: _motherPhoneCtrl.text.trim().isNotEmpty ? _motherPhoneCtrl.text.trim() : null,
        dateOfBirth: _dob,
        gender: _gender,
        caste: _caste.isNotEmpty ? _caste : null,
        category: _category,
        religion: _religion,
        nationality: _nationality,
        bloodGroup: _bloodGroup.isNotEmpty ? _bloodGroup : null,
        address: _addressCtrl.text.trim(),
        city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
        state: _stateCtrl.text.trim().isNotEmpty ? _stateCtrl.text.trim() : null,
        pincode: _pincodeCtrl.text.trim().isNotEmpty ? _pincodeCtrl.text.trim() : null,
        previousSchool: _prevSchoolCtrl.text.trim().isNotEmpty ? _prevSchoolCtrl.text.trim() : null,
        previousClass: _prevClassCtrl.text.trim().isNotEmpty ? _prevClassCtrl.text.trim() : null,
        aadharNumber: _aadharCtrl.text.trim().isNotEmpty ? _aadharCtrl.text.trim() : null,
        admissionDate: DateTime.now(),
        deviceId: 'device_01',
      );

      // 1. Save student locally
      await ref.read(studentRepositoryProvider).addStudent(newStudent);

      // 2. Create logins on backend if opted in
      if (_createAccounts) {
        await _createStudentAccounts(studentId);
        // Success handled inside _createStudentAccounts (shows dialog)
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Student added successfully! ✅'),
              backgroundColor: Colors.green[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (error) {
      setState(() => _isSaving = false);
      if (mounted) _showError(error.toString().replaceAll('Exception:', '').trim());
    }
  }

  Future<void> _createStudentAccounts(String studentId) async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$BASE_URL/admin/create-student-accounts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        'student_id': studentId,
        'student_username': _studentUsernameCtrl.text.trim(),
        'parent_username': _parentUsernameCtrl.text.trim(),
        'password': _passwordCtrl.text,
      }),
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(response.body);

    if (response.statusCode == 409) {
      setState(() => _isSaving = false);
      final dupes = (body['duplicates'] as List?)?.join(', ') ?? '';
      _showError('Username already taken: $dupes\nPlease choose a different username.');
      return;
    }

    if (response.statusCode != 201) {
      setState(() => _isSaving = false);
      _showError(body['message'] ?? 'Failed to create login accounts.');
      return;
    }

    // Show success dialog with credentials summary
    if (mounted) {
      setState(() => _isSaving = false);
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green[600], size: 28),
              const SizedBox(width: 8),
              const Text('Accounts Created!', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Student & Parent logins are ready.\nShare these with the family:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              _credentialRow(Icons.school_rounded, Colors.blue, 'Student Login', _studentUsernameCtrl.text.trim()),
              const SizedBox(height: 10),
              _credentialRow(Icons.family_restroom_rounded, Colors.purple, 'Parent Login', _parentUsernameCtrl.text.trim()),
              const SizedBox(height: 10),
              _credentialRow(Icons.lock_rounded, Colors.orange, 'Password', _passwordCtrl.text),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.amber),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Both accounts share the same password.',
                        style: TextStyle(fontSize: 11, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.of(dialogCtx).pop(); // close dialog only
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
      // Dialog dismissed — now navigate back to students list
      if (mounted) Navigator.pop(context, true);
    }
  }

  Widget _credentialRow(IconData icon, Color color, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Add New Student'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton.icon(
              onPressed: _saveStudent,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Save'),
              style: TextButton.styleFrom(foregroundColor: Colors.green[700]),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Stepper(
          type: StepperType.vertical,
          currentStep: _currentStep,
          physics: const ClampingScrollPhysics(),
          onStepContinue: () {
            if (_currentStep < 4) setState(() => _currentStep++);
            else _saveStudent();
          },
          onStepCancel: () {
            if (_currentStep > 0) setState(() => _currentStep--);
          },
          controlsBuilder: (ctx, details) => Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: details.onStepContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(_currentStep == 4 ? 'Submit' : 'Next'),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 8),
                  TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                ],
              ],
            ),
          ),
          steps: [
            // Step 1: Personal Details
            Step(
              title: const Text('Personal Details', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Name, class, gender, DOB'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  _buildTextField(_nameCtrl, 'Full Name *', Icons.person, required: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_rollCtrl, 'Roll Number *', Icons.tag, required: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildDropdown('Class *', _classId, _classes, (v) => setState(() => _classId = v!))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(_phoneCtrl, 'Phone', Icons.phone, keyboard: TextInputType.phone),
                  const SizedBox(height: 10),
                  _buildTextField(_emailCtrl, 'Email', Icons.email, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('Gender *', _gender, _genders, (v) => setState(() => _gender = v!))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Date of Birth *',
                              prefixIcon: const Icon(Icons.cake_rounded, size: 18),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              isDense: true,
                            ),
                            child: Text('${_dob.day}/${_dob.month}/${_dob.year}', style: const TextStyle(fontSize: 13)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildDropdown('Blood Group', _bloodGroup, _bloodGroups, (v) => setState(() => _bloodGroup = v!))),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_aadharCtrl, 'Aadhar Number', Icons.credit_card, keyboard: TextInputType.number)),
                    ],
                  ),
                ],
              ),
            ),

            // Step 2: Background
            Step(
              title: const Text('Background', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Category, religion, caste'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  _buildDropdown('Category *', _category, _categories, (v) => setState(() => _category = v!)),
                  const SizedBox(height: 10),
                  _buildTextField(TextEditingController(text: _caste), 'Caste', Icons.people_outline,
                      onChanged: (v) => _caste = v),
                  const SizedBox(height: 10),
                  _buildDropdown('Religion', _religion, _religions, (v) => setState(() => _religion = v!)),
                  const SizedBox(height: 10),
                  _buildTextField(
                    TextEditingController(text: _nationality), 'Nationality', Icons.flag,
                    onChanged: (v) => _nationality = v,
                  ),
                ],
              ),
            ),

            // Step 3: Address & Parents
            Step(
              title: const Text('Family & Address', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Parents, address, contact'),
              isActive: _currentStep >= 2,
              state: _currentStep > 2 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  _buildTextField(_fatherNameCtrl, 'Father\'s Name *', Icons.person_outline, required: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_fatherPhoneCtrl, 'Father\'s Phone', Icons.phone, keyboard: TextInputType.phone)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_fatherOccCtrl, 'Occupation', Icons.work_outline)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(_motherNameCtrl, 'Mother\'s Name', Icons.person_outline),
                  const SizedBox(height: 10),
                  _buildTextField(_motherPhoneCtrl, 'Mother\'s Phone', Icons.phone, keyboard: TextInputType.phone),
                  const Divider(height: 24),
                  _buildTextField(_addressCtrl, 'Full Address *', Icons.home_rounded, required: true, maxLines: 2),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_cityCtrl, 'City', Icons.location_city)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildTextField(_stateCtrl, 'State', Icons.map)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(_pincodeCtrl, 'Pin Code', Icons.pin_drop, keyboard: TextInputType.number),
                ],
              ),
            ),

            // Step 4: Previous Education
            Step(
              title: const Text('Previous Education', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Previous school, class'),
              isActive: _currentStep >= 3,
              state: _currentStep > 3 ? StepState.complete : StepState.indexed,
              content: Column(
                children: [
                  _buildTextField(_prevSchoolCtrl, 'Previous School Name', Icons.school_rounded),
                  const SizedBox(height: 10),
                  _buildTextField(_prevClassCtrl, 'Previous Class/Grade', Icons.class_rounded),
                ],
              ),
            ),

            // Step 5: Login Credentials
            Step(
              title: const Text('Login Credentials', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Student & parent login accounts'),
              isActive: _currentStep >= 4,
              state: _currentStep > 4 ? StepState.complete : StepState.indexed,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle to create accounts
                  SwitchListTile(
                    value: _createAccounts,
                    onChanged: (v) => setState(() => _createAccounts = v),
                    title: const Text('Create Login Accounts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Student & parent can log in with these credentials', style: TextStyle(fontSize: 12)),
                    activeColor: Colors.blue[700],
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (_createAccounts) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: Colors.blue),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Usernames are auto-filled from the roll number. You can change them.',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Student username
                    _buildTextField(_studentUsernameCtrl, 'Student Username *', Icons.school_rounded),
                    const SizedBox(height: 10),
                    // Parent username
                    _buildTextField(_parentUsernameCtrl, 'Parent Username *', Icons.family_restroom_rounded),
                    const SizedBox(height: 10),
                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13),
                      validator: (v) {
                        if (!_createAccounts) return null;
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // Confirm password
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password *',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 18),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13),
                      validator: (v) {
                        if (!_createAccounts) return null;
                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Click Submit or Save (top right) to register the student without creating login accounts. You can create them later.',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {
    bool required = false,
    TextInputType? keyboard,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
      validator: required ? (v) => (v == null || v.isEmpty) ? '$label is required' : null : null,
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.isEmpty ? '—' : e, style: const TextStyle(fontSize: 13)))).toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 13, color: Colors.black87),
    );
  }
}
