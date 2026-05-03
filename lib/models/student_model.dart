class StudentModel {
  final String id;
  final String name;
  final String rollNumber;
  final String classId;
  final String? email;
  final String phone;
  final String parentName;
  final String parentPhone;
  final String? parentOccupation;
  final String? motherName;
  final String? motherPhone;
  final String? profileImageUrl;
  final DateTime dateOfBirth;
  final String gender;
  final String? caste;
  final String? category; // General, OBC, SC, ST, EWS
  final String? religion;
  final String? nationality;
  final String? bloodGroup;
  final String address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? previousSchool;
  final String? previousClass;
  final String? aadharNumber;
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
    this.parentOccupation,
    this.motherName,
    this.motherPhone,
    this.profileImageUrl,
    required this.dateOfBirth,
    required this.gender,
    this.caste,
    this.category,
    this.religion,
    this.nationality,
    this.bloodGroup,
    required this.address,
    this.city,
    this.state,
    this.pincode,
    this.previousSchool,
    this.previousClass,
    this.aadharNumber,
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
      parentOccupation: json['parent_occupation'] as String?,
      motherName: json['mother_name'] as String?,
      motherPhone: json['mother_phone'] as String?,
      profileImageUrl: json['profile_image_url'] as String?,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      gender: json['gender'] as String,
      caste: json['caste'] as String?,
      category: json['category'] as String?,
      religion: json['religion'] as String?,
      nationality: json['nationality'] as String?,
      bloodGroup: json['blood_group'] as String?,
      address: json['address'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      previousSchool: json['previous_school'] as String?,
      previousClass: json['previous_class'] as String?,
      aadharNumber: json['aadhar_number'] as String?,
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
      'parent_occupation': parentOccupation,
      'mother_name': motherName,
      'mother_phone': motherPhone,
      'profile_image_url': profileImageUrl,
      'date_of_birth': dateOfBirth.toIso8601String(),
      'gender': gender,
      'caste': caste,
      'category': category,
      'religion': religion,
      'nationality': nationality,
      'blood_group': bloodGroup,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'previous_school': previousSchool,
      'previous_class': previousClass,
      'aadhar_number': aadharNumber,
      'admission_date': admissionDate.toIso8601String(),
      'status': status,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }

  int get age {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month || (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) age--;
    return age;
  }

  StudentModel copyWith({
    String? id,
    String? name,
    String? rollNumber,
    String? classId,
    String? email,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? parentOccupation,
    String? motherName,
    String? motherPhone,
    String? profileImageUrl,
    DateTime? dateOfBirth,
    String? gender,
    String? caste,
    String? category,
    String? religion,
    String? nationality,
    String? bloodGroup,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? previousSchool,
    String? previousClass,
    String? aadharNumber,
    DateTime? admissionDate,
    String? status,
    DateTime? updatedAt,
    String? deviceId,
    bool? isSynced,
    bool? isDeleted,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      classId: classId ?? this.classId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      parentName: parentName ?? this.parentName,
      parentPhone: parentPhone ?? this.parentPhone,
      parentOccupation: parentOccupation ?? this.parentOccupation,
      motherName: motherName ?? this.motherName,
      motherPhone: motherPhone ?? this.motherPhone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      caste: caste ?? this.caste,
      category: category ?? this.category,
      religion: religion ?? this.religion,
      nationality: nationality ?? this.nationality,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      previousSchool: previousSchool ?? this.previousSchool,
      previousClass: previousClass ?? this.previousClass,
      aadharNumber: aadharNumber ?? this.aadharNumber,
      admissionDate: admissionDate ?? this.admissionDate,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      deviceId: deviceId ?? this.deviceId,
      isSynced: isSynced ?? this.isSynced,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
