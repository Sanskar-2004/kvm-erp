class StaffModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String role;
  final String? employeeCode;
  final String? department;
  final String? joiningDate;
  final double salary;
  final String status;
  final String? subjectSpecialization;
  final String? vehicleAssigned;
  final bool canLogin;
  final int? userId;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  StaffModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    required this.role,
    this.employeeCode,
    this.department,
    this.joiningDate,
    this.salary = 0.0,
    this.status = 'active',
    this.subjectSpecialization,
    this.vehicleAssigned,
    this.canLogin = false,
    this.userId,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'employee_code': employeeCode,
      'department': department,
      'joining_date': joiningDate,
      'salary': salary,
      'status': status,
      'subject_specialization': subjectSpecialization,
      'vehicle_assigned': vehicleAssigned,
      'can_login': canLogin ? 1 : 0,
      'user_id': userId,
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map) {
    return StaffModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] ?? '',
      phone: map['phone'],
      email: map['email'],
      role: map['role'] ?? 'peon',
      employeeCode: map['employee_code'],
      department: map['department'],
      joiningDate: map['joining_date'],
      salary: (map['salary'] as num?)?.toDouble() ?? 0.0,
      status: map['status'] ?? 'active',
      subjectSpecialization: map['subject_specialization'],
      vehicleAssigned: map['vehicle_assigned'],
      canLogin: map['can_login'] == 1 || map['can_login'] == true,
      userId: map['user_id'] != null ? int.tryParse(map['user_id'].toString()) : null,
      deviceId: map['device_id']?.toString() ?? 'system',
      isSynced: map['is_synced'] == 1 || map['is_synced'] == true,
      isDeleted: map['is_deleted'] == 1 || map['is_deleted'] == true,
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : DateTime.now(),
    );
  }

  StaffModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? email,
    String? role,
    String? employeeCode,
    String? department,
    String? joiningDate,
    double? salary,
    String? status,
    String? subjectSpecialization,
    String? vehicleAssigned,
    bool? canLogin,
    int? userId,
    String? deviceId,
    bool? isSynced,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      role: role ?? this.role,
      employeeCode: employeeCode ?? this.employeeCode,
      department: department ?? this.department,
      joiningDate: joiningDate ?? this.joiningDate,
      salary: salary ?? this.salary,
      status: status ?? this.status,
      subjectSpecialization: subjectSpecialization ?? this.subjectSpecialization,
      vehicleAssigned: vehicleAssigned ?? this.vehicleAssigned,
      canLogin: canLogin ?? this.canLogin,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
