import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/fee_model.dart';

final feesListProvider = Provider<List<FeeModel>>((ref) {
  return [
    FeeModel(
      id: '1', studentId: '1', studentName: 'Aarav Sharma',
      classId: '10', feeType: 'tuition', amount: 25000,
      paidAmount: 25000, dueAmount: 0, dueDate: DateTime(2026, 3, 31),
      paidDate: DateTime(2026, 3, 10), status: 'paid',
      transactionId: 'TXN001', deviceId: 'mock',
    ),
    FeeModel(
      id: '2', studentId: '2', studentName: 'Priya Verma',
      classId: '10', feeType: 'tuition', amount: 25000,
      paidAmount: 10000, dueAmount: 15000, dueDate: DateTime(2026, 3, 31),
      status: 'partial', deviceId: 'mock',
    ),
    FeeModel(
      id: '3', studentId: '1', studentName: 'Aarav Sharma',
      classId: '10', feeType: 'transport', amount: 5000,
      paidAmount: 0, dueAmount: 5000, dueDate: DateTime(2026, 2, 28),
      status: 'overdue', deviceId: 'mock',
    ),
  ];
});
