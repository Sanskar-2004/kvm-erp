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

    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return FeeModel(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? json['name']?.toString() ?? 'Student',
      classId: json['class_id']?.toString() ?? '',
      feeType: json['fee_type']?.toString() ?? json['month']?.toString() ?? 'Tuition',
      amount: parseNum(json['amount'] ?? json['amount_due']),
      paidAmount: parseNum(json['paid_amount'] ?? json['amount_paid']),
      dueAmount: parseNum(json['due_amount'] ?? ((parseNum(json['amount_due']) - parseNum(json['amount_paid'])))),
      dueDate: parseDate(json['due_date']),
      paidDate: json['paid_date'] != null ? parseDate(json['paid_date']) : null,
      status: json['status']?.toString() ?? 'pending',
      transactionId: json['transaction_id']?.toString(),
      remarks: json['remarks']?.toString(),
      updatedAt: parseDate(json['updated_at']),
      deviceId: json['device_id']?.toString() ?? 'unknown',
      isSynced: parseBool(json['is_synced']),
      isDeleted: parseBool(json['is_deleted']),
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


