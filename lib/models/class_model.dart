class ClassModel {
  final String id;
  final String className;
  final String section;
  final String? stream; // Science, Commerce, Arts (only for classes >= 9)
  final DateTime updatedAt;
  final bool isSynced;
  final bool isDeleted;

  ClassModel({
    required this.id,
    required this.className,
    required this.section,
    this.stream,
    DateTime? updatedAt,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now() {
    // Stream enforcement logic
    final classNum = int.tryParse(className);
    if (classNum != null) {
      if (classNum >= 9 && stream == null) {
        throw ArgumentError('Stream is required for classes 9 and above.');
      }
      if (classNum < 9 && stream != null) {
        throw ArgumentError('Stream is not applicable for classes below 9.');
      }
    }
  }

  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'] as String,
      className: json['class_name'] as String,
      section: json['section'] as String,
      stream: json['stream'] as String?,
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : DateTime.now(),
      isSynced: (json['is_synced'] as int?) == 1,
      isDeleted: (json['is_deleted'] as int?) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_name': className,
      'section': section,
      'stream': stream,
      'updated_at': updatedAt.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}



