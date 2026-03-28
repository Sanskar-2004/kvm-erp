import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/timetable_model.dart';

// Mock timetable data — replace with DB/API fetch
final timetableProvider = Provider<List<TimetableModel>>((ref) {
  return [
    TimetableModel(
      id: '1', classId: '10', day: 'Monday',
      subject: 'Mathematics', teacherId: 't1', teacherName: 'Mr. Kumar',
      startTime: '08:00', endTime: '08:45', periodNumber: 1, deviceId: 'mock',
    ),
    TimetableModel(
      id: '2', classId: '10', day: 'Monday',
      subject: 'English', teacherId: 't2', teacherName: 'Ms. Priya',
      startTime: '08:45', endTime: '09:30', periodNumber: 2, deviceId: 'mock',
    ),
    TimetableModel(
      id: '3', classId: '10', day: 'Monday',
      subject: 'Science', teacherId: 't3', teacherName: 'Dr. Gupta',
      startTime: '09:45', endTime: '10:30', periodNumber: 3, deviceId: 'mock',
    ),
    TimetableModel(
      id: '4', classId: '10', day: 'Tuesday',
      subject: 'Hindi', teacherId: 't4', teacherName: 'Mrs. Devi',
      startTime: '08:00', endTime: '08:45', periodNumber: 1, deviceId: 'mock',
    ),
    TimetableModel(
      id: '5', classId: '10', day: 'Tuesday',
      subject: 'Social Studies', teacherId: 't5', teacherName: 'Mr. Singh',
      startTime: '08:45', endTime: '09:30', periodNumber: 2, deviceId: 'mock',
    ),
  ];
});
