class MarksModel {
  final String id;
  final String studentId;
  final String classId;
  final String subject;
  final String examType; // unit_test, midterm, final, assignment
  final double marksObtained;
  final double totalMarks;
  final String? grade;
  final String? remarks;
  final DateTime examDate;
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  MarksModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.subject,
    required this.examType,
    required this.marksObtained,
    required this.totalMarks,
    this.grade,
    this.remarks,
    required this.examDate,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  double get percentage => (marksObtained / totalMarks) * 100;

  factory MarksModel.fromJson(Map<String, dynamic> json) {
    return MarksModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classId: json['class_id'] as String,
      subject: json['subject'] as String,
      examType: json['exam_type'] as String,
      marksObtained: (json['marks_obtained'] as num).toDouble(),
      totalMarks: (json['total_marks'] as num).toDouble(),
      grade: json['grade'] as String?,
      remarks: json['remarks'] as String?,
      examDate: DateTime.parse(json['exam_date'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      deviceId: json['device_id'] as String? ?? 'unknown',
      isSynced: (json['is_synced'] as int?) == 1,
      isDeleted: (json['is_deleted'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'class_id': classId,
      'subject': subject,
      'exam_type': examType,
      'marks_obtained': marksObtained,
      'total_marks': totalMarks,
      'grade': grade,
      'remarks': remarks,
      'exam_date': examDate.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}


