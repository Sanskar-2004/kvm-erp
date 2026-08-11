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

    return AttendanceModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: json['student_id']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      date: parseDate(json['date']),
      periodNumber: json['period_number'] != null ? int.tryParse(json['period_number'].toString()) : null,
      status: json['status']?.toString() ?? 'present',
      remarks: json['remarks']?.toString(),
      markedBy: json['marked_by']?.toString() ?? 'system',
      updatedAt: parseDate(json['updated_at']),
      deviceId: json['device_id']?.toString() ?? 'unknown',
      isSynced: parseBool(json['is_synced']),
      isDeleted: parseBool(json['is_deleted']),
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



