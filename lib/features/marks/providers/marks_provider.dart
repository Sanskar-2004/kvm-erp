import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/marks_model.dart';
import '../../../core/utils/academic_utils.dart';

final marksListProvider = Provider<List<MarksModel>>((ref) {
  return [
    MarksModel(
      id: '1', studentId: '1', className: '10', section: 'A',
      subject: 'Mathematics', examType: 'midterm',
      marksObtained: 85, totalMarks: 100, 
      grade: AcademicUtils.generateGrade(AcademicUtils.calculatePercentage(85, 100)),
      examDate: DateTime(2026, 2, 15),
    ),
    MarksModel(
      id: '2', studentId: '1', className: '10', section: 'A',
      subject: 'English', examType: 'midterm',
      marksObtained: 72, totalMarks: 100,
      grade: AcademicUtils.generateGrade(AcademicUtils.calculatePercentage(72, 100)),
      examDate: DateTime(2026, 2, 16),
    ),
    MarksModel(
      id: '3', studentId: '1', className: '10', section: 'A',
      subject: 'Science', examType: 'midterm',
      marksObtained: 91, totalMarks: 100,
      grade: AcademicUtils.generateGrade(AcademicUtils.calculatePercentage(91, 100)),
      examDate: DateTime(2026, 2, 17),
    ),
  ];
});
