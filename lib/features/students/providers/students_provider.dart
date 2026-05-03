import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/student_model.dart';
import '../../../models/class_model.dart';

// Mock data — replace with API / DB fetching
final studentsListProvider = Provider<List<StudentModel>>((ref) {
  return [
    StudentModel(
      id: '1',
      name: 'Aarav Sharma',
      rollNumber: '001',
      classId: 'c1', // References a ClassModel with className='10', section='A'
      phone: '9876543210',
      parentName: 'Rajesh Sharma',
      parentPhone: '9876543211',
      dateOfBirth: DateTime(2010, 5, 15),
      gender: 'Male',
      address: '123, Model Town',
      admissionDate: DateTime(2020, 4, 1),
      deviceId: 'mock',
    ),
    StudentModel(
      id: '2',
      name: 'Priya Verma',
      rollNumber: '002',
      classId: 'c1', // References a ClassModel with className='10', section='A'
      phone: '9876543220',
      parentName: 'Sunil Verma',
      parentPhone: '9876543221',
      dateOfBirth: DateTime(2010, 8, 22),
      gender: 'Female',
      address: '456, Civil Lines',
      admissionDate: DateTime(2020, 4, 1),
      deviceId: 'mock',
    ),
  ];
});

// Mock classes for reference
final classesListProvider = Provider<List<ClassModel>>((ref) {
  return [
    ClassModel(id: 'c1', className: '10', section: 'A'),
    ClassModel(id: 'c2', className: '10', section: 'B'),
    ClassModel(id: 'c3', className: '11', section: 'A', stream: 'Science'),
  ];
});
