class PeriodModel {
  final String id;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  PeriodModel({
    required this.id,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory PeriodModel.fromJson(Map<String, dynamic> json) {
    return PeriodModel(
      id: json['id'] as String,
      periodNumber: json['period_number'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
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
      'period_number': periodNumber,
      'start_time': startTime,
      'end_time': endTime,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}


