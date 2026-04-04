import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../models/student_model.dart';
import '../../../../services/db/sqlite_service.dart';

class StudentDetailScreen extends ConsumerStatefulWidget {
  final StudentModel student;
  const StudentDetailScreen({Key? key, required this.student}) : super(key: key);

  @override
  ConsumerState<StudentDetailScreen> createState() => _StudentDetailState();
}

class _StudentDetailState extends ConsumerState<StudentDetailScreen> {
  Map<String, dynamic> _attendanceData = {};
  List<Map<String, dynamic>> _marksData = [];
  List<Map<String, dynamic>> _feeData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    try {
      final db = await SQLiteService().database;

      // Attendance
      final attendance = await db.rawQuery(
        'SELECT status, COUNT(*) as cnt FROM attendance WHERE student_id = ? AND is_deleted = 0 GROUP BY status',
        [widget.student.id],
      );
      final Map<String, dynamic> attMap = {};
      int total = 0;
      for (var row in attendance) {
        attMap[row['status'] as String] = row['cnt'];
        total += (row['cnt'] as int);
      }
      attMap['total'] = total;

      // Marks
      final marks = await db.query(
        'marks',
        where: 'student_id = ? AND is_deleted = 0',
        whereArgs: [widget.student.id],
        orderBy: 'exam_type ASC, subject ASC',
      );

      // Fees
      final fees = await db.query(
        'fees',
        where: 'student_id = ? AND is_deleted = 0',
        whereArgs: [widget.student.id],
        orderBy: 'due_date DESC',
      );

      setState(() {
        _attendanceData = attMap;
        _marksData = marks;
        _feeData = fees;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Load student data error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.student;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(s.name),
          bottom: const TabBar(
            isScrollable: true,
            labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: '  Profile  '),
              Tab(text: '  Attendance  '),
              Tab(text: '  Results  '),
              Tab(text: '  Fees  '),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildProfileTab(s),
                  _buildAttendanceTab(),
                  _buildResultsTab(),
                  _buildFeesTab(),
                ],
              ),
      ),
    );
  }

  // ── PROFILE TAB ──
  Widget _buildProfileTab(StudentModel s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Avatar + Name Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[700]!, Colors.blue[400]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(s.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Roll: ${s.rollNumber} • Class ${s.classId}',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                      if (s.category != null)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${s.category} • ${s.gender}',
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Personal Info
          _sectionCard('Personal Information', Icons.person_rounded, [
            _infoRow('Date of Birth', '${s.dateOfBirth.day}/${s.dateOfBirth.month}/${s.dateOfBirth.year}'),
            _infoRow('Age', '${s.age} years'),
            _infoRow('Gender', s.gender),
            if (s.bloodGroup != null) _infoRow('Blood Group', s.bloodGroup!),
            if (s.aadharNumber != null) _infoRow('Aadhar', s.aadharNumber!),
            _infoRow('Phone', s.phone),
            if (s.email != null) _infoRow('Email', s.email!),
          ]),
          const SizedBox(height: 12),

          // Background
          _sectionCard('Background', Icons.people_rounded, [
            if (s.category != null) _infoRow('Category', s.category!),
            if (s.caste != null) _infoRow('Caste', s.caste!),
            if (s.religion != null) _infoRow('Religion', s.religion!),
            if (s.nationality != null) _infoRow('Nationality', s.nationality!),
          ]),
          const SizedBox(height: 12),

          // Family Info
          _sectionCard('Family Details', Icons.family_restroom_rounded, [
            _infoRow('Father\'s Name', s.parentName),
            _infoRow('Father\'s Phone', s.parentPhone),
            if (s.parentOccupation != null) _infoRow('Occupation', s.parentOccupation!),
            if (s.motherName != null) _infoRow('Mother\'s Name', s.motherName!),
            if (s.motherPhone != null) _infoRow('Mother\'s Phone', s.motherPhone!),
          ]),
          const SizedBox(height: 12),

          // Address
          _sectionCard('Address', Icons.home_rounded, [
            _infoRow('Address', s.address),
            if (s.city != null) _infoRow('City', s.city!),
            if (s.state != null) _infoRow('State', s.state!),
            if (s.pincode != null) _infoRow('Pin Code', s.pincode!),
          ]),
          const SizedBox(height: 12),

          // Previous Education
          if (s.previousSchool != null || s.previousClass != null)
            _sectionCard('Previous Education', Icons.school_rounded, [
              if (s.previousSchool != null) _infoRow('School', s.previousSchool!),
              if (s.previousClass != null) _infoRow('Class/Grade', s.previousClass!),
            ]),
          const SizedBox(height: 12),

          // Admission
          _sectionCard('Admission', Icons.badge_rounded, [
            _infoRow('Admission Date', '${s.admissionDate.day}/${s.admissionDate.month}/${s.admissionDate.year}'),
            _infoRow('Status', s.status.toUpperCase()),
          ]),
        ],
      ),
    );
  }

  // ── ATTENDANCE TAB ──
  Widget _buildAttendanceTab() {
    final total = _attendanceData['total'] ?? 0;
    final present = _attendanceData['Present'] ?? 0;
    final absent = _attendanceData['Absent'] ?? 0;
    final percentage = total > 0 ? ((present / total) * 100) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: percentage >= 75 ? Colors.green.withOpacity(0.06) : Colors.red.withOpacity(0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: percentage >= 75 ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCircle('Total', '$total', Colors.blue),
                    _statCircle('Present', '$present', Colors.green),
                    _statCircle('Absent', '$absent', Colors.red),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total > 0 ? present / total : 0,
                    minHeight: 12,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(percentage >= 75 ? Colors.green : Colors.red),
                  ),
                ),
                const SizedBox(height: 8),
                Text('${percentage.toStringAsFixed(1)}% Attendance',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: percentage >= 75 ? Colors.green[700] : Colors.red[700],
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (total == 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('No attendance records yet', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── RESULTS TAB ──
  Widget _buildResultsTab() {
    if (_marksData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('No exam results yet', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    // Group by exam type
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var m in _marksData) {
      final exam = m['exam_type']?.toString() ?? 'Unknown';
      grouped.putIfAbsent(exam, () => []).add(m);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: grouped.entries.map((entry) {
          double totalObtained = 0;
          double totalMax = 0;
          for (var m in entry.value) {
            totalObtained += (m['marks_obtained'] as num?)?.toDouble() ?? 0;
            totalMax += (m['total_marks'] as num?)?.toDouble() ?? 100;
          }
          final overall = totalMax > 0 ? (totalObtained / totalMax) * 100 : 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.quiz_rounded, color: Colors.blue[700], size: 18),
                      const SizedBox(width: 8),
                      Text(entry.key, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                      const Spacer(),
                      Text('${overall.toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700])),
                    ],
                  ),
                ),
                ...entry.value.map((m) {
                  final obtained = (m['marks_obtained'] as num?)?.toDouble() ?? 0;
                  final total = (m['total_marks'] as num?)?.toDouble() ?? 100;
                  final pct = total > 0 ? (obtained / total) * 100 : 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.06))),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(m['subject']?.toString() ?? '', style: const TextStyle(fontSize: 13)),
                        ),
                        Text('${obtained.toStringAsFixed(0)}/${total.toStringAsFixed(0)}',
                            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: pct >= 60 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${pct.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: pct >= 60 ? Colors.green : Colors.red,
                              )),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── FEES TAB ──
  Widget _buildFeesTab() {
    if (_feeData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Text('No fee records yet', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    double totalDue = 0;
    double totalPaid = 0;
    for (var f in _feeData) {
      totalDue += (f['amount'] as num?)?.toDouble() ?? 0;
      totalPaid += (f['paid_amount'] as num?)?.toDouble() ?? 0;
    }
    final remaining = totalDue - totalPaid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: remaining > 0 ? Colors.red.withOpacity(0.06) : Colors.green.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: remaining > 0 ? Colors.red.withOpacity(0.2) : Colors.green.withOpacity(0.2),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCircle('Total', '₹${totalDue.toStringAsFixed(0)}', Colors.blue),
                    _statCircle('Paid', '₹${totalPaid.toStringAsFixed(0)}', Colors.green),
                    _statCircle('Due', '₹${remaining.toStringAsFixed(0)}', Colors.red),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: totalDue > 0 ? (totalPaid / totalDue).clamp(0, 1) : 0,
                    minHeight: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation(totalPaid >= totalDue ? Colors.green : Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Fee records
          ..._feeData.map((f) {
            final status = f['status']?.toString() ?? 'pending';
            final statusColor = status == 'paid' ? Colors.green : status == 'overdue' ? Colors.red : Colors.orange;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.receipt_rounded, color: statusColor, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f['fee_type']?.toString().toUpperCase() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text('Due: ${f['due_date'] ?? '—'}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${f['amount'] ?? 0}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(status.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helpers ──
  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700], fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _statCircle(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
