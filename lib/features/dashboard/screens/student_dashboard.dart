import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/utils/academic_utils.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../services/sync/sync_service.dart';
import '../../notices/screens/notices_screen.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  Map<String, dynamic> _student = {};
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _academicYear = '2026-2027';
  final List<String> _yearOptions = AcademicUtils.academicYears;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    final studentId = session.userId.toString();

    try {
      // 1. Load from local SQLite FIRST (instant, offline-safe)
      final db = await SQLiteService().database;
      final studentRows = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
      
      bool hasLocalData = studentRows.isNotEmpty;
      
      if (hasLocalData) {
        setState(() => _student = Map<String, dynamic>.from(studentRows.first));
      }

      // 2. Load summary from local SQLite (instant)
      final accurateId = _student['id']?.toString() ?? studentId;
      final localSummary = await SQLiteService().getStudentSummary(accurateId, academicYear: _academicYear);
      
      if (hasLocalData) {
        setState(() {
          _summary = localSummary;
          _isLoading = false; // Show UI immediately with local data
        });
      }

      // 3. Sync in background (non-blocking)
      _syncAndRefresh(session, studentId, hasLocalData);

    } catch (e) {
      debugPrint('Load student data error: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Background sync — if local data exists, refresh silently. If no local data, wait for sync then show.
  void _syncAndRefresh(dynamic session, String studentId, bool hadLocalData) async {
    try {
      await ref.read(syncServiceProvider).runSyncSafe();
    } catch (syncErr) {
      debugPrint('Student dashboard sync error (offline?): $syncErr');
    }

    if (!mounted) return;

    try {
      // Re-query SQLite after sync to pick up any new data
      final db = await SQLiteService().database;
      final studentRows = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
      
      if (studentRows.isNotEmpty) {
        final accurateId = studentRows.first['id']?.toString() ?? studentId;
        final freshSummary = await SQLiteService().getStudentSummary(accurateId, academicYear: _academicYear);
        
        if (mounted) {
          setState(() {
            _student = Map<String, dynamic>.from(studentRows.first);
            _summary = freshSummary;
            _isLoading = false;
          });
        }
      } else if (!hadLocalData) {
        // First login fallback: try HTTP pull directly
        try {
          final fallbackResp = await http.get(
            Uri.parse('$BASE_URL/sync/pull?lastSync=2000-01-01T00:00:00.000Z'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          ).timeout(const Duration(seconds: 8));
          if (fallbackResp.statusCode == 200) {
            final pullData = jsonDecode(fallbackResp.body);
            final students = List<Map<String, dynamic>>.from(pullData['data']['students'] ?? []);
            final match = students.where((s) => s['id'].toString() == studentId).toList();
            if (match.isNotEmpty && mounted) {
              setState(() {
                _student = match.first;
                _isLoading = false;
              });
            }
          }
        } catch (e) {
          debugPrint('HTTP fallback error: $e');
        }
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Post-sync refresh error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Dashboard'),
        actions: [
          DropdownButton<String>(
            value: _academicYear,
            underline: const SizedBox(),
            icon: const Icon(Icons.calendar_today, size: 16),
            items: _yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _academicYear = v;
                  _isLoading = true;
                });
                _loadStudentData();
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudentData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text('My Dashboard',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to refresh',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 12),

              // ── Student Profile Card ──
              _buildProfileCard(),
              const SizedBox(height: 16),

              // ── Loading or tiles ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // Attendance
                _InteractiveTile(
                  title: 'Attendance',
                  value: '${_summary['attendance']?['percentage'] ?? '—'}%',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  status: _getAttendanceStatus(),
                  onTap: _showAttendanceDetail,
                ),
                const SizedBox(height: 12),

                // Fee Status
                _InteractiveTile(
                  title: 'Fee Status',
                  value: _getFeeSummary(),
                  icon: Icons.payments_rounded,
                  color: _getFeeColor(),
                  status: _getFeeStatus(),
                  onTap: _showFeeDetail,
                ),
                const SizedBox(height: 12),

                // Exam Results
                _InteractiveTile(
                  title: 'Exam Results',
                  value: _getMarksValue(),
                  icon: Icons.grading_rounded,
                  color: Colors.blue,
                  status: _getMarksStatus(),
                  onTap: _showMarksDetail,
                ),
                const SizedBox(height: 12),

                // Alerts
                _InteractiveTile(
                  title: 'Notices & Alerts',
                  value: '${(_summary['alerts'] as List?)?.length ?? 0} Items',
                  icon: Icons.notifications_rounded,
                  color: Colors.orange,
                  status: _getAlertStatus(),
                  onTap: _showAlertsDetail,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Profile Card ──
  Widget _buildProfileCard() {
    final name = _student['name']?.toString() ?? 'Student';
    final classId = _student['class_id']?.toString() ?? '-';
    final rollNumber = _student['roll_number']?.toString() ?? '-';
    final gender = _student['gender']?.toString() ?? '-';
    final parentName = _student['parent_name']?.toString() ?? '-';
    final parentPhone = _student['parent_phone']?.toString() ?? '-';
    final phone = _student['phone']?.toString() ?? '-';

    return InkWell(
      onTap: _showFullProfile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple[700]!, Colors.purple[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white24,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const SizedBox(height: 4),
                  Text('Class $classId  •  Roll: $rollNumber',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Icon(Icons.person_outline_rounded,
                        size: 13, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text('$gender  •  $phone',
                        style: const TextStyle(
                            color: Colors.white60, fontSize: 11)),
                  ]),
                ],
              ),
            ),
            Column(children: [
              Icon(Icons.info_outline_rounded, color: Colors.white60, size: 20),
              const SizedBox(height: 4),
              Text('Profile',
                  style: TextStyle(color: Colors.white60, fontSize: 9)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Full Profile Sheet ──
  void _showFullProfile() {
    final name = _student['name']?.toString() ?? '-';
    final classId = _student['class_id']?.toString() ?? '-';
    final rollNumber = _student['roll_number']?.toString() ?? '-';
    final gender = _student['gender']?.toString() ?? '-';
    final dob = _student['date_of_birth']?.toString().split('T').first ?? '-';
    final phone = _student['phone']?.toString() ?? '-';
    final email = _student['email']?.toString() ?? '-';
    final parentName = _student['parent_name']?.toString() ?? '-';
    final parentPhone = _student['parent_phone']?.toString() ?? '-';
    final parentOccupation = _student['parent_occupation']?.toString() ?? '-';
    final motherName = _student['mother_name']?.toString() ?? '-';
    final motherPhone = _student['mother_phone']?.toString() ?? '-';
    final address = _student['address']?.toString() ?? '-';
    final city = _student['city']?.toString() ?? '';
    final state = _student['state']?.toString() ?? '';
    final pincode = _student['pincode']?.toString() ?? '';
    final fullAddress = [address, city, state, pincode]
        .where((s) => s.isNotEmpty && s != '-')
        .join(', ');
    final category = _student['category']?.toString() ?? '-';
    final religion = _student['religion']?.toString() ?? '-';
    final nationality = _student['nationality']?.toString() ?? '-';
    final bloodGroup = _student['blood_group']?.toString() ?? '-';
    final aadhar = _student['aadhar_number']?.toString() ?? '-';
    final admissionDate =
        _student['admission_date']?.toString().split('T').first ?? '-';
    final previousSchool = _student['previous_school']?.toString() ?? '-';
    final previousClass = _student['previous_class']?.toString() ?? '-';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.purple.withOpacity(0.12),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: TextStyle(
                            color: Colors.purple[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 28)),
                  ),
                  const SizedBox(height: 10),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('Class $classId  •  Roll: $rollNumber',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 20),

              // Personal Info
              _sectionHeader('Personal Information'),
              _infoRow('Gender', gender),
              _infoRow('Date of Birth', dob),
              _infoRow('Blood Group', bloodGroup),
              _infoRow('Phone', phone),
              _infoRow('Email', email),
              _infoRow('Aadhar Number', aadhar),

              const SizedBox(height: 16),
              _sectionHeader('Background'),
              _infoRow('Category', category),
              _infoRow('Religion', religion),
              _infoRow('Nationality', nationality),

              const SizedBox(height: 16),
              _sectionHeader('Family Details'),
              _infoRow("Father's Name", parentName),
              _infoRow("Father's Phone", parentPhone),
              _infoRow("Father's Occupation", parentOccupation),
              _infoRow("Mother's Name", motherName),
              _infoRow("Mother's Phone", motherPhone),

              const SizedBox(height: 16),
              _sectionHeader('Address'),
              _infoRow(
                  'Full Address', fullAddress.isNotEmpty ? fullAddress : '-'),

              const SizedBox(height: 16),
              _sectionHeader('Education'),
              _infoRow('Admission Date', admissionDate),
              _infoRow('Previous School', previousSchool),
              _infoRow('Previous Class', previousClass),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                color: Colors.purple, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.purple[700])),
      ]),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 130,
              child: Text(label,
                  style: TextStyle(color: Colors.grey[500], fontSize: 13))),
          Expanded(
              child: Text(value.isEmpty || value == 'null' ? '-' : value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  // ── Summary Helpers ──
  String _getAttendanceStatus() {
    final pct = double.tryParse(
            _summary['attendance']?['percentage']?.toString() ?? '0') ??
        0;
    if (pct >= 90) return 'Excellent';
    if (pct >= 75) return 'Good';
    if (pct >= 50) return 'Needs Improvement';
    return 'Critical';
  }

  String _getFeeSummary() {
    final due =
        double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid =
        double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ??
            0;
    final remaining = due - paid;
    if (remaining <= 0) return 'All Clear';
    return '₹${remaining.toStringAsFixed(0)} Due';
  }

  Color _getFeeColor() {
    final due =
        double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid =
        double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ??
            0;
    return (due - paid) > 0 ? Colors.red : Colors.green;
  }

  String _getFeeStatus() {
    final due =
        double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid =
        double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ??
            0;
    return (due - paid) > 0 ? 'Overdue' : 'Paid';
  }

  String _getMarksValue() {
    final marks = _summary['marks'] as List? ?? [];
    if (marks.isEmpty) return 'No Results';
    return '${marks.length} Subjects';
  }

  String _getMarksStatus() {
    final marks = _summary['marks'] as List? ?? [];
    if (marks.isEmpty) return 'Pending';
    return 'Published';
  }

  String _getAlertStatus() {
    final alerts = _summary['alerts'] as List? ?? [];
    final unread = alerts.where((a) => a['is_read'] == false).length;
    return unread > 0 ? '$unread Unread' : 'All Read';
  }

  // ── Detail Sheets ──
  void _showAttendanceDetail() {
    final att = _summary['attendance'] ?? {};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Attendance Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _detailStat('Total', '${att['total'] ?? 0}', Colors.blue),
            _detailStat('Present', '${att['present'] ?? 0}', Colors.green),
            _detailStat('Absent',
                '${(att['total'] ?? 0) - (att['present'] ?? 0)}', Colors.red),
          ]),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value:
                  (double.tryParse(att['percentage']?.toString() ?? '0') ?? 0) /
                      100,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Colors.green),
            ),
          ),
          const SizedBox(height: 8),
          Text('${att['percentage'] ?? 0}% Attendance Rate',
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: Colors.grey[600])),
        ]),
      ),
    );
  }

  void _showFeeDetail() {
    final fees = _summary['fees'] ?? {};
    final due = double.tryParse(fees['total_due']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(fees['total_paid']?.toString() ?? '0') ?? 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Fee Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _detailStat('Total Due', '₹${due.toStringAsFixed(0)}', Colors.blue),
            _detailStat('Paid', '₹${paid.toStringAsFixed(0)}', Colors.green),
            _detailStat(
                'Remaining', '₹${(due - paid).toStringAsFixed(0)}', Colors.red),
          ]),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: due > 0 ? (paid / due).clamp(0, 1) : 0,
              minHeight: 12,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation(
                  paid >= due ? Colors.green : Colors.orange),
            ),
          ),
        ]),
      ),
    );
  }

  void _showMarksDetail() {
    final marks = List<Map<String, dynamic>>.from(_summary['marks'] ?? []);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('Report Card',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: marks.isEmpty
                  ? Center(
                      child: Text('No results yet',
                          style: TextStyle(color: Colors.grey[400])))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: marks.length,
                      itemBuilder: (ctx, i) {
                        final m = marks[i];
                        final obtained = double.tryParse(
                                m['marks_obtained']?.toString() ?? '0') ??
                            0;
                        final total = double.tryParse(
                                m['total_marks']?.toString() ?? '100') ??
                            100;
                        final pct = total > 0 ? (obtained / total) * 100 : 0;
                        final grade =
                            AcademicUtils.generateGrade(pct.toDouble());

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.blue.withOpacity(0.12)),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(m['subject']?.toString() ?? 'Subject',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    Text(
                                        '${m['exam_type'] ?? ''} • Rank: ${m['class_rank'] ?? '-'}',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                  ]),
                            ),
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      '${obtained.toStringAsFixed(0)}/${total.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  Text('Grade: $grade',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue[700],
                                          fontWeight: FontWeight.w600)),
                                ]),
                          ]),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  void _showAlertsDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NoticesScreen(canCreate: false)),
    );
  }

  Widget _detailStat(String label, String value, Color color) {
    return Column(children: [
      Text(value,
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
    ]);
  }
}

// ── Reusable Interactive Tile ──
class _InteractiveTile extends StatelessWidget {
  final String title, value, status;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _InteractiveTile({
    required this.title,
    required this.value,
    required this.status,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 3),
              Text(value,
                  style: TextStyle(
                      color: color, fontSize: 18, fontWeight: FontWeight.bold)),
            ]),
          ),
          Column(children: [
            Chip(
              label: Text(status,
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold)),
              backgroundColor: color.withOpacity(0.1),
              side: BorderSide.none,
              visualDensity: VisualDensity.compact,
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withOpacity(0.4), size: 20),
          ]),
        ]),
      ),
    );
  }
}
