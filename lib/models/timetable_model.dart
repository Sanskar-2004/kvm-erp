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
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime(2000, 1, 1);
      final s = val.toString().trim();
      if (s.isEmpty) return DateTime(2000, 1, 1);
      return DateTime.tryParse(s.replaceAll(' ', 'T')) ?? DateTime.tryParse(s) ?? DateTime(2000, 1, 1);
    }

    bool parseBool(dynamic val) {
      if (val == null) return false;
      if (val is bool) return val;
      if (val is num) return val == 1;
      final s = val.toString().toLowerCase().trim();
      return s == '1' || s == 'true';
    }

    return TimetableModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      classId: json['class_id']?.toString() ?? '',
      day: json['day']?.toString() ?? 'Monday',
      subject: json['subject']?.toString() ?? 'Subject',
      teacherId: json['teacher_id']?.toString() ?? '',
      teacherName: json['teacher_name']?.toString() ?? 'Teacher',
      startTime: json['start_time']?.toString() ?? '09:00',
      endTime: json['end_time']?.toString() ?? '10:00',
      periodNumber: int.tryParse(json['period_number']?.toString() ?? '1') ?? 1,
      updatedAt: parseDate(json['updated_at']),
      deviceId: json['device_id']?.toString() ?? 'unknown',
      isSynced: parseBool(json['is_synced']),
      isDeleted: parseBool(json['is_deleted']),
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


