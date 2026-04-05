import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../services/db/sqlite_service.dart';

/// Student-only fee screen — shows ONLY the logged-in student's fee data
class StudentFeeScreen extends ConsumerStatefulWidget {
  const StudentFeeScreen({super.key});

  @override
  ConsumerState<StudentFeeScreen> createState() => _StudentFeeScreenState();
}

class _StudentFeeScreenState extends ConsumerState<StudentFeeScreen> {
  Map<String, dynamic> _fees = {};
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _studentName = 'Student';

  @override
  void initState() {
    super.initState();
    _loadMyFees();
  }

  Future<void> _loadMyFees() async {
    setState(() => _isLoading = true);
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final summary = await SQLiteService().getStudentSummary(session.userId);
      final txns =
          await SQLiteService().getStudentFeeTransactions(session.userId);

      // Student name can be pulled from local db if needed, or we just leave it contextually
      final db = SQLiteService();
      final studentCheck = await db.query('students',
          where: 'id = ?', whereArgs: [session.userId], limit: 1);
      if (studentCheck.isNotEmpty) {
        _studentName = studentCheck.first['name']?.toString() ?? 'Student';
      }

      setState(() {
        _fees = summary['fees'] ?? {};
        _transactions = txns;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load fees error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalDue =
        double.tryParse(_fees['total_due']?.toString() ?? '0') ?? 0;
    final totalPaid =
        double.tryParse(_fees['total_paid']?.toString() ?? '0') ?? 0;
    final remaining = totalDue - totalPaid;
    final paidPercent =
        totalDue > 0 ? (totalPaid / totalDue).clamp(0.0, 1.0) : 0.0;

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMyFees,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Fees',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Pull down to refresh',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 16),

                    // ── Summary Card ──
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: remaining > 0
                              ? [Colors.red[700]!, Colors.red[400]!]
                              : [Colors.green[700]!, Colors.green[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Fee',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12)),
                                  Text('₹${totalDue.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 28)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                    remaining <= 0 ? '✅ ALL CLEAR' : '⚠️ DUE',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: paidPercent,
                              minHeight: 10,
                              backgroundColor: Colors.white24,
                              valueColor:
                                  const AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _miniStat(
                                  'Paid', '₹${totalPaid.toStringAsFixed(0)}'),
                              _miniStat('Pending',
                                  '₹${remaining.toStringAsFixed(0)}'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Transaction History ──
                    Text('Payment History',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey[800])),
                    const SizedBox(height: 12),

                    if (_transactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('No payment records yet',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_transactions.length, (i) {
                        final txn = _transactions[i];
                        final amount = double.tryParse(
                                txn['amount_paid']?.toString() ?? '0') ??
                            0;
                        final month = txn['month']?.toString() ?? '-';
                        final status = txn['status']?.toString() ?? 'UNPAID';
                        final method = txn['payment_method']?.toString() ?? '-';
                        final date =
                            txn['paid_date']?.toString().split('T').first ??
                                '-';
                        final isPaid = status == 'PAID';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isPaid
                                ? Colors.green.withOpacity(0.04)
                                : Colors.red.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: isPaid
                                    ? Colors.green.withOpacity(0.15)
                                    : Colors.red.withOpacity(0.15)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                    isPaid
                                        ? Icons.check_circle_rounded
                                        : Icons.pending_rounded,
                                    color: isPaid ? Colors.green : Colors.red,
                                    size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(month,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text('$method • $date',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${amount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isPaid
                                              ? Colors.green[700]
                                              : Colors.red[700])),
                                  Text(status,
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isPaid
                                              ? Colors.green
                                              : Colors.red)),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 11)),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ],
    );
  }
}
