class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final String classId;
  final String? email;
  final String phone;
  final String parentName;
  final String parentPhone;
  final String? profileImageUrl;
  final DateTime dateOfBirth;
  final String gender;
  final String address;
  final DateTime admissionDate;
  final String status; // pending | approved | rejected
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  StudentModel({
    required this.id,
    required this.name,
    required this.rollNumber,
    required this.classId,
    this.email,
    required this.phone,
    required this.parentName,
    required this.parentPhone,
    this.profileImageUrl,
    required this.dateOfBirth,
    required this.gender,
    required this.address,
    required this.admissionDate,
    this.status = 'approved',
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      name: json['name'] as String,
      rollNumber: json['roll_number'] as String,
      classId: json['class_id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String,
      parentName: json['parent_name'] as String,
      parentPhone: json['parent_phone'] as String,
      profileImageUrl: json['profile_image_url'] as String?,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      gender: json['gender'] as String,
      address: json['address'] as String,
      admissionDate: DateTime.parse(json['admission_date'] as String),
      status: json['status'] as String? ?? 'approved',
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
      'name': name,
      'roll_number': rollNumber,
      'class_id': classId,
      'email': email,
      'phone': phone,
      'parent_name': parentName,
      'parent_phone': parentPhone,
      'profile_image_url': profileImageUrl,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'address': address,
      'admission_date': admissionDate.toIso8601String(),
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}

