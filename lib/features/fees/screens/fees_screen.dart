import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../students/repositories/student_repository.dart';
import '../../../../models/student_model.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/class_constants.dart';
import '../../../core/utils/academic_utils.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../dashboard/screens/student_fee_detail_screen.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  String _selectedClass = 'All';
  String _selectedStatus = 'All'; // All, Paid, Due
  String _selectedYear = AcademicUtils.academicYears.last; // Default to current year
  Map<String, Map<String, dynamic>> _feeMap = {}; // studentId -> fee summary
  bool _isLoading = true;

  final _classes = ClassConstants.allClassesWithAll;

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  Future<void> _loadFeeData() async {
    setState(() => _isLoading = true);
    try {
      // Step 1: Try to sync fees from backend (background-safe)
      try {
        final session = await ref.read(authRepositoryProvider).getSession();
        if (session != null) {
          final response = await http.get(
            Uri.parse('$BASE_URL/sync/pull?lastSync=2000-01-01T00:00:00.000Z'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          ).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final rawFees = List<Map<String, dynamic>>.from(
                data['data']['student_fees'] ?? []);
            if (rawFees.isNotEmpty) {
              await SQLiteService().upsertStudentFees(rawFees);
            }
          }
        }
      } catch (syncError) {
        debugPrint('[FeesScreen] Sync pull failed (offline?): $syncError');
      }

      // Step 2: Query local SQLite filtered by selected academic year
      final db = await SQLiteService().database;
      final fees = await db.rawQuery('''
        SELECT sf.student_id, s.name as student_name, s.class_id,
               SUM(sf.amount_due) as total_amount,
               SUM(sf.amount_paid) as total_paid,
               SUM(sf.amount_due - sf.amount_paid) as total_due,
               MAX(sf.paid_date) as last_paid,
               sf.academic_year
        FROM student_fees sf
        LEFT JOIN students s ON s.id = sf.student_id
        WHERE sf.is_deleted = 0 AND sf.academic_year = ?
        GROUP BY sf.student_id, sf.academic_year
        ORDER BY s.class_id ASC, s.name ASC
      ''', [_selectedYear]);

      final map = <String, Map<String, dynamic>>{};
      for (var row in fees) {
        map[row['student_id'] as String] = row;
      }

      setState(() {
        _feeMap = map;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Fee load error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref
        .watch(studentRepositoryProvider)
        .getAllStudents(limit: 500, offset: 0);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text('Fee Management'),
      ),
      body: FutureBuilder<List<StudentModel>>(
        future: studentsAsync,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              _isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final allStudents = snapshot.data ?? [];
          if (allStudents.isEmpty) {
            return const Center(
                child: Text('No students found. Add students first.'));
          }

          // Filter students
          var students = allStudents.where((s) {
            if (_selectedClass != 'All' && s.classId != _selectedClass)
              return false;
            if (_selectedStatus != 'All') {
              final fee = _feeMap[s.id];
              if (fee == null && _selectedStatus != 'Due') return false;
              if (fee != null) {
                final due = (fee['total_due'] as num?)?.toDouble() ?? 0;
                if (_selectedStatus == 'Paid' && due > 0) return false;
                if (_selectedStatus == 'Due' && due <= 0) return false;
              }
            }
            return true;
          }).toList();

          // Calculate totals for selected year
          double grandTotal = 0;
          double grandPaid = 0;
          for (var fee in _feeMap.values) {
            grandTotal += (fee['total_amount'] as num?)?.toDouble() ?? 0;
            grandPaid += (fee['total_paid'] as num?)?.toDouble() ?? 0;
          }

          return Column(
            children: [
              // Controls
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.04),
                  border: Border(
                      bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Column(
                  children: [
                    // Year + Class + Status filters
                    Row(
                      children: [
                        // Year dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.teal.withOpacity(0.3)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedYear,
                                isExpanded: true,
                                icon: const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                                style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                                items: AcademicUtils.academicYears
                                    .map((y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(y),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedYear = v);
                                    _loadFeeData();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Class dropdown
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClass,
                                isExpanded: true,
                                items: _classes
                                    .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(
                                              c == 'All'
                                                  ? 'All Classes'
                                                  : 'Class $c',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _selectedClass = v ?? 'All'),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Status dropdown
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedStatus,
                              items: ['All', 'Paid', 'Due']
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s,
                                            style: const TextStyle(
                                                fontSize: 13)),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(
                                  () => _selectedStatus = v ?? 'All'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Grand total banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green[700]!, Colors.green[500]!],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _bannerStat(
                              'Total Fee', '₹${grandTotal.toStringAsFixed(0)}'),
                          Container(
                              width: 1, height: 30, color: Colors.white30),
                          _bannerStat(
                              'Collected', '₹${grandPaid.toStringAsFixed(0)}'),
                          Container(
                              width: 1, height: 30, color: Colors.white30),
                          _bannerStat('Due',
                              '₹${(grandTotal - grandPaid).toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Student count
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text('${students.length} Students • $_selectedYear',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 13)),
                    const Spacer(),
                    Text('Tap to manage fees →',
                        style:
                            TextStyle(color: Colors.teal[300], fontSize: 11)),
                  ],
                ),
              ),

              // Student Fee List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: students.length,
                  itemBuilder: (ctx, index) {
                    final student = students[index];
                    final fee = _feeMap[student.id];

                    final totalAmount =
                        (fee?['total_amount'] as num?)?.toDouble() ?? 0;
                    final totalPaid =
                        (fee?['total_paid'] as num?)?.toDouble() ?? 0;
                    final totalDue = totalAmount - totalPaid;

                    String status;
                    Color statusColor;
                    if (fee == null) {
                      status = 'NO FEE';
                      statusColor = Colors.grey;
                    } else if (totalDue <= 0) {
                      status = 'PAID';
                      statusColor = Colors.green;
                    } else {
                      status = 'DUE';
                      statusColor = Colors.red;
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: statusColor.withOpacity(0.15)),
                      ),
                      child: ListTile(
                        onTap: () async {
                          // Navigate to full fee detail screen with edit capability
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentFeeDetailScreen(
                                studentId: student.id,
                                studentName: student.name,
                                classId: student.classId,
                              ),
                            ),
                          );
                          // Refresh data after returning
                          _loadFeeData();
                        },
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: statusColor.withOpacity(0.1),
                          child: Icon(
                            status == 'PAID'
                                ? Icons.check_circle_rounded
                                : status == 'DUE'
                                    ? Icons.warning_rounded
                                    : Icons.remove_circle_outline,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        title: Text(student.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                        subtitle: Text(
                          'Roll: ${student.rollNumber} • Class ${student.classId}',
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (totalAmount > 0)
                              Text(
                                  '₹${totalPaid.toStringAsFixed(0)} / ₹${totalAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(status,
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bannerStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15)),
        Text(label,
            style:
                TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
      ],
    );
  }
}
