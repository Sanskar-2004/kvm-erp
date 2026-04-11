import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/utils/academic_utils.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../services/sync/sync_service.dart';

class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;
  Map<String, dynamic> _summary = {};
  Map<String, dynamic> _studentDetails = {};
  String? _parentName;
  bool _isLoading = true;
  String _academicYear = '2026-2027';
  final List<String> _yearOptions = ['2024-2025', '2025-2026', '2026-2027', '2027-2028'];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/parent/children/${session.userId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final children =
            List<Map<String, dynamic>>.from(data['children'] ?? []);
        setState(() {
           _children = children;
           // Attempt to derive Parent Name from session if stored, otherwise from first child
           if (session.role == 'parent') {
              // Usually the session object itself has basic info or we fetch from user table
           }
        });

        // Fetch parent name from local DB for the header
        final db = await SQLiteService().database;
        final userRows = await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
        if (userRows.isNotEmpty) {
           setState(() => _parentName = userRows.first['name']?.toString());
        }

        if (children.isNotEmpty) {
          _loadStudentSummary(children[0]['id']);
        } else {
          // No linked children natively on the backend — let's magically match by phone!
          try {
             await ref.read(syncServiceProvider).runSyncSafe();
          } catch (_) {}

          final db = await SQLiteService().database;

          // 1. Fetch current parent's phone/username
          final userRows = await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
          String? parentContact;
          if (userRows.isNotEmpty) {
             parentContact = userRows.first['username']?.toString();
             if (parentContact == null || parentContact.isEmpty) {
                 parentContact = userRows.first['email']?.toString();
             }
          }

          List<Map<String, Object?>> matchedStudents = [];
          
          if (parentContact != null && parentContact.trim().isNotEmpty) {
             // 2. Fetch all valid students that share this exact phone number!
             matchedStudents = await db.query(
                'students', 
                where: 'is_deleted = 0 AND (parent_phone = ? OR phone = ? OR email = ?)', 
                whereArgs: [parentContact, parentContact, parentContact]
             );
          }

          // 3. Populate dashboard safely
          if (matchedStudents.isNotEmpty) {
             setState(() {
                _children = matchedStudents.map((s) => {
                   'id': s['id'].toString(),
                   'name': s['name'].toString(),
                   'class_id': s['class_id'].toString(),
                }).toList();
             });
             _loadStudentSummary(matchedStudents.first['id'].toString());
          } else {
             // Absolutely no children match. Don't show random students like "sd"
             setState(() {
                _children = [
                   {'id': 'demo123', 'name': 'No Child Linked', 'class_id': '-'}
                ];
                _isLoading = false; 
             });
             // Empty mock summary so the fee tiles load gracefully as cleared
             setState(() {
                _summary = {
                   'attendance': {'percentage': '0'},
                   'fees': {'total_due': 0, 'total_paid': 0},
                   'marks': [],
                   'alerts': []
                };
             });
          }
          return;
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Load children error: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStudentSummary(String studentId) async {
    setState(() => _isLoading = true);
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    try {
      // 1. Run global background sync fully native locally
      try {
        await ref.read(syncServiceProvider).runSyncSafe();
      } catch (syncErr) {
        debugPrint('Parent dashboard sync error (offline?): $syncErr');
      }

      // 2. Fetch comprehensive summary securely from SQLite
      final localSummary = await SQLiteService().getStudentSummary(studentId, academicYear: _academicYear);
      setState(() => _summary = localSummary);

      // 3. Fetch detailed student profile directly from SQLite 
      final db = await SQLiteService().database;
      final studentRows = await db.query('students', where: 'id = ?', whereArgs: [studentId]);
      
      if (studentRows.isNotEmpty) {
        setState(() => _studentDetails = Map<String, dynamic>.from(studentRows.first));
      } else {
        final child = _children.isNotEmpty ? _children[_selectedChildIndex] : <String, dynamic>{};
        setState(() => _studentDetails = Map<String, dynamic>.from(child));
      }
    } catch (e) {
      debugPrint('Summary error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_parentName ?? "Parent"}\'s Dashboard'),
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
                _loadStudentSummary(_children[_selectedChildIndex]['id']);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadChildren,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                _parentName != null ? '$_parentName\'s Dashboard' : "Parent Dashboard",
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('Pull down to refresh',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12)),
              const SizedBox(height: 12),

              // ── Sibling Toggle ──
              if (_children.length > 1)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _children.length,
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final isSelected = index == _selectedChildIndex;

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedChildIndex = index);
                          _loadStudentSummary(child['id']);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.green
                                : Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                                color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.child_care_rounded,
                                  size: 18,
                                  color:
                                      isSelected ? Colors.white : Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                child['name'] ?? 'Child ${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              // ── Child Profile Card ──
              if (!_isLoading && _children.isNotEmpty) _buildChildProfileCard(),

              if (!_isLoading && _children.isNotEmpty)
                const SizedBox(height: 14),

              // ── Loading State ──
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // ── Attendance Tile ──
                _InteractiveTile(
                  title: 'Attendance',
                  value: '${_summary['attendance']?['percentage'] ?? '—'}%',
                  icon: Icons.check_circle_rounded,
                  color: Colors.green,
                  status: _getAttendanceStatus(),
                  onTap: () => _showAttendanceDetail(),
                ),
                const SizedBox(height: 12),

                // ── Fee Tile ──
                _InteractiveTile(
                  title: 'Fee Status',
                  value: _getFeeSummary(),
                  icon: Icons.payments_rounded,
                  color: _getFeeColor(),
                  status: _getFeeStatus(),
                  onTap: () => _showFeeDetail(),
                ),
                const SizedBox(height: 12),

                // ── Marks Tile ──
                _InteractiveTile(
                  title: 'Exam Results',
                  value: _getMarksValue(),
                  icon: Icons.grading_rounded,
                  color: Colors.blue,
                  status: _getMarksStatus(),
                  onTap: () => _showMarksDetail(),
                ),
                const SizedBox(height: 12),

                // ── Alerts Tile ──
                _InteractiveTile(
                  title: 'Notices & Alerts',
                  value: '${(_summary['alerts'] as List?)?.length ?? 0} Items',
                  icon: Icons.notifications_rounded,
                  color: Colors.orange,
                  status: _getAlertStatus(),
                  onTap: () => _showAlertsDetail(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
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

  // ── Child Profile Card ──
  Widget _buildChildProfileCard() {
    // Use _studentDetails if available, fallback to basic _children data
    final source = _studentDetails.isNotEmpty
        ? _studentDetails
        : (_children.isNotEmpty
            ? _children[_selectedChildIndex]
            : <String, dynamic>{});
    final name = source['name']?.toString() ?? '-';
    final classId = source['class_id']?.toString() ?? '-';
    final rollNumber = source['roll_number']?.toString() ?? '-';
    final gender = source['gender']?.toString() ?? '-';
    final phone = source['phone']?.toString() ?? '-';

    return InkWell(
      onTap: _showFullChildProfile,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[700]!, Colors.green[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.white24,
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 17)),
                  const SizedBox(height: 3),
                  Text('Class $classId  •  Roll: $rollNumber',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('$gender  •  $phone',
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            Column(children: [
              const Icon(Icons.info_outline_rounded,
                  color: Colors.white60, size: 20),
              const SizedBox(height: 4),
              const Text('Details',
                  style: TextStyle(color: Colors.white60, fontSize: 9)),
            ]),
          ],
        ),
      ),
    );
  }

  // ── Full Child Profile Sheet ──
  void _showFullChildProfile() {
    final s = _studentDetails.isNotEmpty
        ? _studentDetails
        : (_children.isNotEmpty
            ? _children[_selectedChildIndex]
            : <String, dynamic>{});
    final name = s['name']?.toString() ?? '-';
    final classId = s['class_id']?.toString() ?? '-';
    final rollNumber = s['roll_number']?.toString() ?? '-';
    final gender = s['gender']?.toString() ?? '-';
    final dob = s['date_of_birth']?.toString().split('T').first ?? '-';
    final phone = s['phone']?.toString() ?? '-';
    final email = s['email']?.toString() ?? '-';
    final parentName = s['parent_name']?.toString() ?? '-';
    final parentPhone = s['parent_phone']?.toString() ?? '-';
    final parentOccupation = s['parent_occupation']?.toString() ?? '-';
    final motherName = s['mother_name']?.toString() ?? '-';
    final motherPhone = s['mother_phone']?.toString() ?? '-';
    final address = s['address']?.toString() ?? '-';
    final city = s['city']?.toString() ?? '';
    final state = s['state']?.toString() ?? '';
    final pincode = s['pincode']?.toString() ?? '';
    final fullAddress = [address, city, state, pincode]
        .where((v) => v.isNotEmpty && v != '-')
        .join(', ');
    final category = s['category']?.toString() ?? '-';
    final religion = s['religion']?.toString() ?? '-';
    final nationality = s['nationality']?.toString() ?? '-';
    final bloodGroup = s['blood_group']?.toString() ?? '-';
    final aadhar = s['aadhar_number']?.toString() ?? '-';
    final admissionDate =
        s['admission_date']?.toString().split('T').first ?? '-';
    final previousSchool = s['previous_school']?.toString() ?? '-';
    final previousClass = s['previous_class']?.toString() ?? '-';

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
              Center(
                child: Column(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.green.withOpacity(0.12),
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C',
                        style: TextStyle(
                            color: Colors.green[700],
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
              _profileSection('Personal Information'),
              _profileRow('Gender', gender),
              _profileRow('Date of Birth', dob),
              _profileRow('Blood Group', bloodGroup),
              _profileRow('Phone', phone),
              _profileRow('Email', email),
              _profileRow('Aadhar Number', aadhar),
              const SizedBox(height: 16),
              _profileSection('Background'),
              _profileRow('Category', category),
              _profileRow('Religion', religion),
              _profileRow('Nationality', nationality),
              const SizedBox(height: 16),
              _profileSection('Family Details'),
              _profileRow("Father's Name", parentName),
              _profileRow("Father's Phone", parentPhone),
              _profileRow("Father's Occupation", parentOccupation),
              _profileRow("Mother's Name", motherName),
              _profileRow("Mother's Phone", motherPhone),
              const SizedBox(height: 16),
              _profileSection('Address'),
              _profileRow(
                  'Full Address', fullAddress.isNotEmpty ? fullAddress : '-'),
              const SizedBox(height: 16),
              _profileSection('Education'),
              _profileRow('Admission Date', admissionDate),
              _profileRow('Previous School', previousSchool),
              _profileRow('Previous Class', previousClass),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
                color: Colors.green, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.green[700])),
      ]),
    );
  }

  Widget _profileRow(String label, String value) {
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

  // ── Detail Sheets ──
  void _showAttendanceDetail() {
    final att = _summary['attendance'] ?? {};
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Attendance Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStat('Total Days', '${att['total'] ?? 0}', Colors.blue),
                _detailStat('Present', '${att['present'] ?? 0}', Colors.green),
                _detailStat(
                    'Absent',
                    '${(att['total'] ?? 0) - (att['present'] ?? 0)}',
                    Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (double.tryParse(att['percentage']?.toString() ?? '0') ??
                        0) /
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
          ],
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Fee Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStat(
                    'Total Due', '₹${due.toStringAsFixed(0)}', Colors.blue),
                _detailStat(
                    'Paid', '₹${paid.toStringAsFixed(0)}', Colors.green),
                _detailStat('Remaining', '₹${(due - paid).toStringAsFixed(0)}',
                    Colors.red),
              ],
            ),
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
          ],
        ),
      ),
    );
  }

  void _showMarksDetail() {
    final marks = List<Map<String, dynamic>>.from(_summary['marks'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
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
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          m['subject']?.toString() ?? 'Subject',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14)),
                                      Text(
                                          '${m['exam_type'] ?? ''} • Rank: ${m['class_rank'] ?? '-'}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                    ],
                                  ),
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

  void _showAlertsDetail() {
    final alerts = List<Map<String, dynamic>>.from(_summary['alerts'] ?? []);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        expand: false,
        builder: (ctx, scrollCtrl) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text('Notices & Alerts',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: alerts.isEmpty
                    ? Center(
                        child: Text('No alerts',
                            style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: alerts.length,
                        itemBuilder: (ctx, i) {
                          final alert = alerts[i];
                          final isRead = alert['is_read'] == true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? Colors.grey.withOpacity(0.04)
                                  : Colors.orange.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isRead
                                      ? Colors.grey.withOpacity(0.1)
                                      : Colors.orange.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isRead
                                      ? Icons.check_circle_outline
                                      : Icons.notifications_active_rounded,
                                  color: isRead ? Colors.grey : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(alert['message']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isRead
                                                ? FontWeight.normal
                                                : FontWeight.w600,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(
                                          alert['created_at']?.toString() ?? '',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[400])),
                                    ],
                                  ),
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

  Widget _detailStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 20)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ],
    );
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
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              children: [
                Chip(
                  label: Text(status,
                      style: TextStyle(
                          color: color,
                          fontSize: 9,
                          fontWeight: FontWeight.bold)),
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.chevron_right_rounded,
                    color: color.withOpacity(0.4), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
