class AttendanceModel {
  final String id;
  final String studentId;
  final String classId; // Linked to ClassModel via foreign key
  final DateTime date;
  final int? periodNumber;
  final String status; // present, absent, late, excused
  final String? remarks;
  final String markedBy; // teacher ID
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  AttendanceModel({
    required this.id,
    required this.studentId,
    required this.classId,
    required this.date,
    this.periodNumber,
    required this.status,
    this.remarks,
    required this.markedBy,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      classId: json['class_id'] as String,
      date: DateTime.parse(json['date'] as String),
      periodNumber: json['period_number'] as int?,
      status: json['status'] as String,
      remarks: json['remarks'] as String?,
      markedBy: json['marked_by'] as String,
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
      'date': date.toIso8601String(),
      'period_number': periodNumber,
      'status': status,
      'remarks': remarks,
      'marked_by': markedBy,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}



