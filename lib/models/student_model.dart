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

    return StudentModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name']?.toString() ?? 'Student',
      rollNumber: json['roll_number']?.toString() ?? 'N/A',
      classId: json['class_id']?.toString() ?? 'Unknown',
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ?? 'N/A',
      parentName: json['parent_name']?.toString() ?? 'N/A',
      parentPhone: json['parent_phone']?.toString() ?? 'N/A',
      parentOccupation: json['parent_occupation']?.toString(),
      motherName: json['mother_name']?.toString(),
      motherPhone: json['mother_phone']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      dateOfBirth: parseDate(json['date_of_birth']),
      gender: json['gender']?.toString() ?? 'Male',
      caste: json['caste']?.toString(),
      category: json['category']?.toString(),
      religion: json['religion']?.toString(),
      nationality: json['nationality']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      address: json['address']?.toString() ?? 'N/A',
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      pincode: json['pincode']?.toString(),
      previousSchool: json['previous_school']?.toString(),
      previousClass: json['previous_class']?.toString(),
      aadharNumber: json['aadhar_number']?.toString(),
      admissionDate: parseDate(json['admission_date']),
      status: json['status']?.toString() ?? 'approved',
      updatedAt: parseDate(json['updated_at']),
      deviceId: json['device_id']?.toString() ?? 'unknown',
      isSynced: parseBool(json['is_synced']),
      isDeleted: parseBool(json['is_deleted']),
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
