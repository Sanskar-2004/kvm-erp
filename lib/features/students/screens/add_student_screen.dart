import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/student_repository.dart';
import '../../../core/constants/class_constants.dart';
import '../../../../models/student_model.dart';
import '../../../../core/utils/validator_service.dart';

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

  static final _classes = ClassConstants.allClasses;
  static const _genders = ['Male', 'Female', 'Other'];
  static const _categories = ['General', 'OBC', 'SC', 'ST', 'EWS'];
  static const _religions = ['Hindu', 'Muslim', 'Christian', 'Sikh', 'Buddhist', 'Jain', 'Other'];
  static const _bloodGroups = ['', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

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

    setState(() => _isSaving = true);
    try {
      ValidatorService.validateStudent(_nameCtrl.text, _rollCtrl.text, _phoneCtrl.text);

      final newStudent = StudentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
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

      await ref.read(studentRepositoryProvider).addStudent(newStudent);

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
    } catch (error) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceAll("Exception:", "")),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            if (_currentStep < 3) setState(() => _currentStep++);
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
                  child: Text(_currentStep == 3 ? 'Submit' : 'Next'),
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
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Colors.blue[700], size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Click Submit or Save (top right) to register the student.',
                            style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                          ),
                        ),
                      ],
                    ),
                  ),
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
