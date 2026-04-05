import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/class_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../fees/providers/fee_analytics_provider.dart';
import 'student_fee_detail_screen.dart';

class AccountantDashboard extends ConsumerStatefulWidget {
  const AccountantDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<AccountantDashboard> createState() =>
      _AccountantDashboardState();
}

class _AccountantDashboardState extends ConsumerState<AccountantDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;

  // Fees overview data
  Map<String, dynamic> _yearly = {};
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _dueStudents = [];
  int _unpaidStudentCount = 0;
  double _grandTotalDue = 0;
  bool _isFeesLoading = false;

  // Class filter
  String _selectedClass = 'All';
  List<String> _classes = List<String>.from(ClassConstants.allClassesWithAll);

  static const _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
    _loadFeesOverview();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  double _parseNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      final response = await http.get(
        Uri.parse('$BASE_URL/sync/pull?lastSync=2000-01-01T00:00:00.000Z'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final students =
            List<Map<String, dynamic>>.from(data['data']['students'] ?? [])
                .where((s) => s['is_deleted'] != 1)
                .toList();

        // Extract unique classes - handle both numeric and string class IDs
        final classSet = <String>{'All'};
        for (final s in students) {
          final classId = s['class_id']?.toString();
          if (classId != null && classId.isNotEmpty) {
            classSet.add(classId);
          }
        }

        // Merge dynamic classes with canonical list so ALL classes always show
        final sortedClasses = ClassConstants.allClasses;

        setState(() {
          _students = students;
          _classes = ['All', ...sortedClasses];
        });
      }
    } catch (e) {
      debugPrint('Load students error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFeesOverview() async {
    setState(() => _isFeesLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      // By using ref.refresh, we FORCE the provider to bypass cache and query SQLite again, 
      // ensuring immediately fresh data after a sync occurs.
      final finance = await ref.refresh(feeAnalyticsProvider.future);

      setState(() {
        _yearly = {
          'total_paid': finance['collected'],
          'total_pending': finance['pending'],
          'total_due': finance['expected']
        };
        _recentTransactions =
            List<Map<String, dynamic>>.from(finance['transactions'] ?? []);
        _unpaidStudentCount = finance['due_students'] ?? 0;

        _dueStudents =
            List<Map<String, dynamic>>.from(finance['due_students_list'] ?? []);
        _grandTotalDue = _parseNum(finance['pending']);
      });
    } catch (e) {
      debugPrint('Load fees overview error: $e');
    } finally {
      setState(() => _isFeesLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    var list = _students;
    if (_selectedClass != 'All') {
      list = list
          .where((s) => s['class_id']?.toString() == _selectedClass)
          .toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((s) =>
              (s['name'] ?? '').toString().toLowerCase().contains(query) ||
              (s['class_id'] ?? '').toString().toLowerCase().contains(query))
          .toList();
    }
    return list;
  }

  Future<void> _sendAlert(String studentId, String studentName) async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    await http.post(
      Uri.parse('$BASE_URL/fees/alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        'user_id': studentId,
        'message':
            'Fee payment reminder: Your fee for $studentName is overdue. Please clear your dues at the earliest.',
      }),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.notifications_active, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Alert sent to $studentName\'s parent'),
        ]),
        backgroundColor: Colors.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
                color: Colors.teal, borderRadius: BorderRadius.circular(10)),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '  Students  '),
              Tab(text: '  Fees Overview  '),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStudentsTab(),
              _buildFeesOverviewTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── TAB 1: Students with Class Selector ──
  Widget _buildStudentsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: [
            // Class Selector Dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.withOpacity(0.15)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedClass,
                  isExpanded: true,
                  icon:
                      const Icon(Icons.filter_list_rounded, color: Colors.teal),
                  items: _classes.map((c) {
                    String label;
                    if (c == 'All') {
                      label = 'All Classes';
                    } else if (int.tryParse(c) != null) {
                      label = 'Class $c';
                    } else {
                      label = c; // Nursery, KG1, KG2
                    }
                    return DropdownMenuItem(
                      value: c,
                      child: Text(label,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedClass = v ?? 'All'),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Search
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search student...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${_filteredStudents.length} students',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500)),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search,
                              size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('No students found',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        final student = _filteredStudents[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.teal.withOpacity(0.1),
                              child: Text(
                                (student['name'] ?? 'S')[0].toUpperCase(),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                    fontSize: 14),
                              ),
                            ),
                            title: Text(student['name'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text(
                                'Class ${student['class_id'] ?? '-'}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[500])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.notifications_active_rounded,
                                      color: Colors.orange[600], size: 20),
                                  tooltip: 'Alert Parent',
                                  onPressed: () => _sendAlert(
                                    student['id'] ?? '',
                                    student['name'] ?? 'Student',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                                const Icon(Icons.chevron_right_rounded,
                                    color: Colors.teal, size: 20),
                              ],
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => StudentFeeDetailScreen(
                                        studentId: student['id'] ?? '',
                                        studentName:
                                            student['name'] ?? 'Unknown',
                                        classId:
                                            student['class_id']?.toString() ??
                                                '-',
                                      )),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // ── TAB 2: Fees Overview ──
  Widget _buildFeesOverviewTab() {
    final totalExpected = _parseNum(_yearly['total_due']);
    final totalCollected = _parseNum(_yearly['total_paid']);
    final totalPending = _parseNum(_yearly['total_pending']);
    final progress = totalExpected > 0
        ? (totalCollected / totalExpected).clamp(0.0, 1.0)
        : 0.0;
    final paidStudents = _students.length - _unpaidStudentCount;

    return _isFeesLoading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadFeesOverview,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Summary Cards ──
                  Row(children: [
                    Expanded(
                        child: _statCard(
                            'Expected',
                            '₹${totalExpected.toStringAsFixed(0)}',
                            Icons.account_balance_rounded,
                            Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _statCard(
                            'Collected',
                            '₹${totalCollected.toStringAsFixed(0)}',
                            Icons.trending_up_rounded,
                            Colors.green)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _statCard(
                            'Pending',
                            '₹${totalPending.toStringAsFixed(0)}',
                            Icons.trending_down_rounded,
                            Colors.red)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _statCard('Due Students', '$_unpaidStudentCount',
                            Icons.person_off_rounded, Colors.orange)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: _statCard(
                            'Paid Students',
                            '${paidStudents > 0 ? paidStudents : 0}',
                            Icons.check_circle_rounded,
                            Colors.teal)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: _statCard(
                            'Total Students',
                            '${_students.length}',
                            Icons.people_rounded,
                            Colors.indigo)),
                  ]),
                  const SizedBox(height: 16),

                  // ── Collection Progress ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.withOpacity(0.12)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Collection Progress',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 14)),
                            Text('${(progress * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700])),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progress > 0.7
                                  ? Colors.green
                                  : progress > 0.4
                                      ? Colors.orange
                                      : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Last 10 Transactions ──
                  Text('Last 10 Transactions',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  if (_recentTransactions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('No transactions yet',
                            style: TextStyle(color: Colors.grey[500])),
                      ]),
                    )
                  else
                    ...List.generate(_recentTransactions.length, (index) {
                      final txn = _recentTransactions[index];
                      final amount = _parseNum(txn['amount_paid']);
                      final totalDue = _parseNum(txn['amount_due']);
                      final remaining = totalDue - amount;
                      final month =
                          txn['month'] is int ? txn['month'] as int : 0;
                      final method = txn['payment_method']?.toString() ?? 'N/A';
                      final paidDate =
                          txn['paid_date']?.toString().split('T').first ?? '';

                      final methodIcon = method == 'UPI'
                          ? Icons.phone_android_rounded
                          : method == 'Cheque'
                              ? Icons.description_rounded
                              : method == 'Bank Transfer'
                                  ? Icons.account_balance_rounded
                                  : Icons.money_rounded;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.green.withOpacity(0.1),
                            child: Text('${index + 1}',
                                style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      txn['student_name']?.toString() ??
                                          'Unknown',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Row(children: [
                                    Icon(methodIcon,
                                        size: 13, color: Colors.grey[400]),
                                    const SizedBox(width: 4),
                                    Text(method,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500])),
                                    if (month > 0 && month <= 12) ...[
                                      const SizedBox(width: 6),
                                      Text('• ${_monthNames[month - 1]}',
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500])),
                                    ],
                                    if (paidDate.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Text('• $paidDate',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey[400])),
                                    ],
                                  ]),
                                ]),
                          ),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('₹${amount.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                        fontSize: 15)),
                                if (remaining > 0)
                                  Text('Left: ₹${remaining.toStringAsFixed(0)}',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red[400],
                                          fontWeight: FontWeight.w500)),
                              ]),
                        ]),
                      );
                    }),

                  // ── Due Students Quick List ──
                  if (_dueStudents.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Students with Dues',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                              '₹${_grandTotalDue.toStringAsFixed(0)} total',
                              style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(
                      _dueStudents.length > 10 ? 10 : _dueStudents.length,
                      (index) {
                        final student = _dueStudents[index];
                        final due = _parseNum(student['total_due']);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.red.withOpacity(0.1)),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.red.withOpacity(0.1),
                              child: Text(
                                  (student['student_name'] ?? 'S')[0]
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            title: Text(student['student_name'] ?? 'Unknown',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                            subtitle: Text(
                                'Class ${student['class_id'] ?? '-'} • Due: ₹${due.toStringAsFixed(0)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.red[400])),
                            trailing: IconButton(
                              icon: Icon(Icons.notifications_active_rounded,
                                  color: Colors.orange[700], size: 20),
                              tooltip: 'Send Alert',
                              onPressed: () => _sendAlert(
                                  student['student_id'] ?? '',
                                  student['student_name'] ?? 'Student'),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: TextStyle(
                    color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
