class TimetableModel {
  final String id;
  final String classId; // Linked to ClassModel via foreign key
  final String day; // Monday, Tuesday, etc.
  final String subject;
  final String teacherId;
  final String teacherName;
  final String startTime;
  final String endTime;
  final int periodNumber;
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  TimetableModel({
    required this.id,
    required this.classId,
    required this.day,
    required this.subject,
    required this.teacherId,
    required this.teacherName,
    required this.startTime,
    required this.endTime,
    required this.periodNumber,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory TimetableModel.fromJson(Map<String, dynamic> json) {
    return TimetableModel(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      day: json['day'] as String,
      subject: json['subject'] as String,
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      periodNumber: json['period_number'] as int,
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
      'class_id': classId,
      'day': day,
      'subject': subject,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'start_time': startTime,
      'end_time': endTime,
      'period_number': periodNumber,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}


