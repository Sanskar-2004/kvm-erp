import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../students/repositories/student_repository.dart';
import '../../../../models/student_model.dart';
import '../../../../services/db/sqlite_service.dart';
import '../../../core/constants/class_constants.dart';

class FeesScreen extends ConsumerStatefulWidget {
  const FeesScreen({super.key});

  @override
  ConsumerState<FeesScreen> createState() => _FeesScreenState();
}

class _FeesScreenState extends ConsumerState<FeesScreen> {
  String _selectedClass = 'All';
  String _selectedStatus = 'All'; // All, Paid, Due, Overdue
  Map<String, Map<String, dynamic>> _feeMap = {}; // studentId -> fee summary
  bool _isLoading = true;

  final _classes = ClassConstants.allClassesWithAll;

  @override
  void initState() {
    super.initState();
    _loadFeeData();
  }

  Future<void> _loadFeeData() async {
    try {
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
        WHERE sf.is_deleted = 0
        GROUP BY sf.student_id
        ORDER BY s.class_id ASC, s.name ASC
      ''');

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

          // Calculate totals
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
                    // Class + Status filters
                    Row(
                      children: [
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
                                value: _selectedStatus,
                                isExpanded: true,
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
                    Text('${students.length} Students',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            fontSize: 13)),
                    const Spacer(),
                    Icon(Icons.sort_rounded, size: 16, color: Colors.grey[400]),
                    Text(' Class wise',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 11)),
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
                    } else if (totalDue > 0) {
                      status = 'DUE';
                      statusColor = Colors.red;
                    } else {
                      status = 'PARTIAL';
                      statusColor = Colors.orange;
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
                        onTap: () => _showStudentFeeDetail(student, fee),
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

  void _showStudentFeeDetail(
      StudentModel student, Map<String, dynamic>? feeSummary) async {
    // Load detailed fee records from student_fees
    List<Map<String, dynamic>> records = [];
    try {
      final db = await SQLiteService().database;
      records = await db.query(
        'student_fees',
        where: 'student_id = ? AND is_deleted = 0',
        whereArgs: [student.id],
        orderBy: 'month ASC',
      );
    } catch (e) {
      debugPrint('Fee detail error: $e');
    }

    final totalAmount = (feeSummary?['total_amount'] as num?)?.toDouble() ?? 0;
    final totalPaid = (feeSummary?['total_paid'] as num?)?.toDouble() ?? 0;
    final totalDue = totalAmount - totalPaid;

    if (!mounted) return;

    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue.withOpacity(0.1),
                    child: Text(student.name[0],
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700])),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(student.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                            'Roll: ${student.rollNumber} • Class ${student.classId}',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: totalDue > 0
                      ? Colors.red.withOpacity(0.06)
                      : Colors.green.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _detailStat('Total Fee',
                            '₹${totalAmount.toStringAsFixed(0)}', Colors.blue),
                        _detailStat('Paid', '₹${totalPaid.toStringAsFixed(0)}',
                            Colors.green),
                        _detailStat('Due', '₹${totalDue.toStringAsFixed(0)}',
                            Colors.red),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: totalAmount > 0
                            ? (totalPaid / totalAmount).clamp(0, 1)
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation(
                            totalPaid >= totalAmount
                                ? Colors.green
                                : Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Records
              Expanded(
                child: records.isEmpty
                    ? Center(
                        child: Text('No fee records',
                            style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: records.length,
                        itemBuilder: (ctx, i) {
                          final r = records[i];
                          final status = (r['status']?.toString() ?? 'UNPAID').toUpperCase();
                          final amountDue = (r['amount_due'] as num?)?.toDouble() ?? 0;
                          final amountPaid = (r['amount_paid'] as num?)?.toDouble() ?? 0;
                          final monthNum = (r['month'] as int?) ?? 0;
                          final monthLabel = (monthNum >= 1 && monthNum <= 12)
                              ? monthNames[monthNum - 1]
                              : 'Month $monthNum';
                          final sColor = status == 'PAID'
                              ? Colors.green
                              : status == 'PARTIAL'
                                  ? Colors.orange
                                  : Colors.red;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: sColor.withOpacity(0.15)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  status == 'PAID'
                                      ? Icons.check_circle
                                      : Icons.schedule,
                                  color: sColor,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          monthLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12)),
                                      Text(
                                          r['paid_date'] != null
                                              ? 'Paid: ${r['paid_date'].toString().split('T').first}'
                                              : 'Not yet paid',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('₹${amountDue.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    if (amountPaid > 0)
                                      Text('Paid: ₹${amountPaid.toStringAsFixed(0)}',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[600])),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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

  Widget _detailStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }
}
