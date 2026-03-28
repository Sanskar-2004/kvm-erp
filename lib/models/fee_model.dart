class FeeModel {
  final String id;
  final String studentId;
  final String studentName;
  final String classId;
  final String feeType; // tuition, transport, lab, library, exam
  final double amount;
  final double paidAmount;
  final double dueAmount;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String status; // paid, pending, overdue, partial
  final String? transactionId;
  final String? remarks;
  final DateTime updatedAt;
  final String deviceId;
  final bool isSynced;
  final bool isDeleted;

  FeeModel({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.classId,
    required this.feeType,
    required this.amount,
    required this.paidAmount,
    required this.dueAmount,
    required this.dueDate,
    this.paidDate,
    required this.status,
    this.transactionId,
    this.remarks,
    DateTime? updatedAt,
    required this.deviceId,
    this.isSynced = false,
    this.isDeleted = false,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isOverdue =>
      status != 'paid' && DateTime.now().isAfter(dueDate);

  factory FeeModel.fromJson(Map<String, dynamic> json) {
    return FeeModel(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      studentName: json['student_name'] as String,
      classId: json['class_id'] as String,
      feeType: json['fee_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      dueAmount: (json['due_amount'] as num).toDouble(),
      dueDate: DateTime.parse(json['due_date'] as String),
      paidDate: json['paid_date'] != null
          ? DateTime.parse(json['paid_date'] as String)
          : null,
      status: json['status'] as String,
      transactionId: json['transaction_id'] as String?,
      remarks: json['remarks'] as String?,
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
      'student_id': studentId,
      'student_name': studentName,
      'class_id': classId,
      'fee_type': feeType,
      'amount': amount,
      'paid_amount': paidAmount,
      'due_amount': dueAmount,
      'due_date': dueDate.toIso8601String(),
      'paid_date': paidDate?.toIso8601String(),
      'status': status,
      'transaction_id': transactionId,
      'remarks': remarks,
      'updated_at': updatedAt.toIso8601String(),
      'device_id': deviceId,
      'is_synced': isSynced ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
    };
  }
}


