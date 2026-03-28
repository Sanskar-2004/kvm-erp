class NoticeModel {
  final String id;
  final String title;
  final String description;
  final String postedBy;
  final String targetAudience; // all, teachers, students, parents
  final DateTime postedAt;
  final DateTime? expiresAt;
  final bool isImportant;
  final String? attachmentUrl;
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  NoticeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.postedBy,
    required this.targetAudience,
    required this.postedAt,
    this.expiresAt,
    this.isImportant = false,
    this.attachmentUrl,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    return NoticeModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      postedBy: json['posted_by'] as String,
      targetAudience: json['target_audience'] as String,
      postedAt: DateTime.parse(json['posted_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isImportant: json['is_important'] as bool? ?? false,
      attachmentUrl: json['attachment_url'] as String?,
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
      'title': title,
      'description': description,
      'posted_by': postedBy,
      'target_audience': targetAudience,
      'posted_at': postedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_important': isImportant,
      'attachment_url': attachmentUrl,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}


