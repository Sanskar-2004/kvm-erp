class StaffAssignmentModel {
  final String id;
  final String staffId;
  final String classId;
  final String subject;
  final String academicYear;
  final int maxPeriodsPerDay;
  final int maxPeriodsPerWeek;
  final bool isClassTeacher;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Joins
  final String? staffName;
  final String? role;

  StaffAssignmentModel({
    required this.id,
    required this.staffId,
    required this.classId,
    required this.subject,
    this.academicYear = '2026-27',
    this.maxPeriodsPerDay = 6,
    this.maxPeriodsPerWeek = 30,
    this.isClassTeacher = false,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.staffName,
    this.role,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'staff_id': staffId,
      'class_id': classId,
      'subject': subject,
      'academic_year': academicYear,
      'max_periods_per_day': maxPeriodsPerDay,
      'max_periods_per_week': maxPeriodsPerWeek,
      'is_class_teacher': isClassTeacher ? 1 : 0,
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StaffAssignmentModel.fromMap(Map<String, dynamic> map) {
    return StaffAssignmentModel(
      id: map['id']?.toString() ?? '',
      staffId: map['staff_id']?.toString() ?? '',
      classId: map['class_id']?.toString() ?? '',
      subject: map['subject'] ?? '',
      academicYear: map['academic_year'] ?? '2026-27',
      maxPeriodsPerDay: map['max_periods_per_day'] != null ? int.parse(map['max_periods_per_day'].toString()) : 6,
      maxPeriodsPerWeek: map['max_periods_per_week'] != null ? int.parse(map['max_periods_per_week'].toString()) : 30,
      isClassTeacher: map['is_class_teacher'] == 1 || map['is_class_teacher'] == true,
      deviceId: map['device_id']?.toString() ?? 'system',
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
      staffName: map['staff_name'],
      role: map['role'],
    );
  }

  StaffAssignmentModel copyWith({
    String? id,
    String? staffId,
    String? classId,
    String? subject,
    String? academicYear,
    int? maxPeriodsPerDay,
    int? maxPeriodsPerWeek,
    bool? isClassTeacher,
    String? deviceId,
    bool? isSynced,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffAssignmentModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      classId: classId ?? this.classId,
      subject: subject ?? this.subject,
      academicYear: academicYear ?? this.academicYear,
      maxPeriodsPerDay: maxPeriodsPerDay ?? this.maxPeriodsPerDay,
      maxPeriodsPerWeek: maxPeriodsPerWeek ?? this.maxPeriodsPerWeek,
      isClassTeacher: isClassTeacher ?? this.isClassTeacher,
      deviceId: deviceId ?? this.deviceId,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      staffName: staffName,
      role: role,
    );
  }
}
