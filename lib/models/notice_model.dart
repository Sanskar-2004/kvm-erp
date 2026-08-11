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

    return NoticeModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title']?.toString() ?? 'Notice',
      description: json['description']?.toString() ?? '',
      postedBy: json['posted_by']?.toString() ?? 'Admin',
      targetAudience: json['target_audience']?.toString() ?? 'all',
      postedAt: parseDate(json['posted_at']),
      expiresAt: json['expires_at'] != null ? parseDate(json['expires_at']) : null,
      isImportant: parseBool(json['is_important']),
      attachmentUrl: json['attachment_url']?.toString(),
      updatedAt: parseDate(json['updated_at']),
      deviceId: json['device_id']?.toString() ?? 'unknown',
      isSynced: parseBool(json['is_synced']),
      isDeleted: parseBool(json['is_deleted']),
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


