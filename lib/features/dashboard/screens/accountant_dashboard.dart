import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';

class AccountantDashboard extends ConsumerStatefulWidget {
  const AccountantDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<AccountantDashboard> createState() => _AccountantDashboardState();
}

class _AccountantDashboardState extends ConsumerState<AccountantDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _dueStudents = [];
  double _grandTotal = 0;
  bool _isLoading = false;
  bool _isDueLoading = false;

  // Class filter
  String _selectedClass = 'All';
  List<String> _classes = ['All'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadStudents();
    _loadDueFees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
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
        final students = List<Map<String, dynamic>>.from(data['data']['students'] ?? []);

        // Extract unique classes
        final classSet = <String>{'All'};
        for (final s in students) {
          if (s['class_id'] != null) classSet.add(s['class_id'].toString());
        }

        setState(() {
          _students = students;
          _classes = classSet.toList()..sort();
        });
      }
    } catch (e) {
      debugPrint('Load students error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDueFees() async {
    setState(() => _isDueLoading = true);
    try {
      final session = await ref.read(authRepositoryProvider).getSession();
      if (session == null) return;

      final response = await http.get(
        Uri.parse('$BASE_URL/admin/due-fees'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dueStudents = List<Map<String, dynamic>>.from(data['students'] ?? []);
          _grandTotal = (data['grandTotal'] ?? 0).toDouble();
          _isDueLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isDueLoading = false);
      debugPrint('Load due fees error: $e');
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    var list = _students;
    if (_selectedClass != 'All') {
      list = list.where((s) => s['class_id']?.toString() == _selectedClass).toList();
    }
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) =>
        (s['name'] ?? '').toString().toLowerCase().contains(query) ||
        (s['class_id'] ?? '').toString().toLowerCase().contains(query)
      ).toList();
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
        'message': 'Fee payment reminder: Your fee for $studentName is overdue. Please clear your dues at the earliest.',
      }),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.notifications_active, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Alert sent to $studentName'),
          ]),
          backgroundColor: Colors.teal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.circular(10),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey[600],
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: '  Students  '),
              Tab(text: '  Due Fees  '),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildStudentsTab(),
              _buildDueFeesTab(),
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
          child: Column(
            children: [
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
                    icon: const Icon(Icons.filter_list_rounded, color: Colors.teal),
                    items: _classes.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c == 'All' ? 'All Classes' : 'Class $c',
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    )).toList(),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Student count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_filteredStudents.length} students',
              style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w500),
            ),
          ),
        ),
        const SizedBox(height: 4),

        // List
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search, size: 56, color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          Text('No students found', style: TextStyle(color: Colors.grey[500])),
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
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal, fontSize: 14),
                              ),
                            ),
                            title: Text(student['name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Class ${student['class_id'] ?? '-'}',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.teal, size: 20),
                            onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => FeeCalendarScreen(
                                studentId: student['id'], studentName: student['name'] ?? 'Unknown',
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

  // ── TAB 2: Due Fees Overview ──
  Widget _buildDueFeesTab() {
    return Column(
      children: [
        // Grand Total Banner
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red[700]!, Colors.red[400]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.account_balance_wallet, color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Pending Revenue', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    '₹${_grandTotal.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${_dueStudents.length}\nstudents',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        // Unpaid Students List
        Expanded(
          child: _isDueLoading
              ? const Center(child: CircularProgressIndicator())
              : _dueStudents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 56, color: Colors.green[300]),
                          const SizedBox(height: 8),
                          Text('All fees collected!', style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _dueStudents.length,
                      itemBuilder: (context, index) {
                        final student = _dueStudents[index];
                        final due = double.tryParse(student['total_due']?.toString() ?? '0') ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.12)),
                          ),
                          child: ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.red.withOpacity(0.1),
                              child: Text(
                                (student['student_name'] ?? 'S')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            title: Text(student['student_name'] ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('Class ${student['class_id'] ?? '-'} • Due: ₹${due.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 12, color: Colors.red[400])),
                            trailing: IconButton(
                              icon: Icon(Icons.notifications_active_rounded, color: Colors.orange[700], size: 22),
                              tooltip: 'Send Alert',
                              onPressed: () => _sendAlert(
                                student['student_id'] ?? '',
                                student['student_name'] ?? 'Student',
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

// ── Fee Calendar Screen (12-Month View with Discount Math) ──
class FeeCalendarScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;

  const FeeCalendarScreen({Key? key, required this.studentId, required this.studentName}) : super(key: key);

  @override
  ConsumerState<FeeCalendarScreen> createState() => _FeeCalendarScreenState();
}

class _FeeCalendarScreenState extends ConsumerState<FeeCalendarScreen> {
  List<Map<String, dynamic>> _fees = [];
  bool _isLoading = true;
  final String _academicYear = '2026-2027';

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _loadFees();
  }

  Future<void> _loadFees() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/fees/${widget.studentId}/$_academicYear'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _fees = List<Map<String, dynamic>>.from(data['fees']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Load fees error: $e');
    }
  }

  // Summary calculations
  double get _totalDue => _fees.fold(0, (sum, f) => sum + (double.tryParse(f['amount_due']?.toString() ?? '0') ?? 0));
  double get _totalPaid => _fees.fold(0, (sum, f) => sum + (double.tryParse(f['amount_paid']?.toString() ?? '0') ?? 0));
  double get _totalDiscount => _fees.fold(0, (sum, f) => sum + (double.tryParse(f['discount_amount']?.toString() ?? '0') ?? 0));
  double get _netRemaining => _totalDue - _totalPaid - _totalDiscount;
  int get _paidCount => _fees.where((f) => f['status'] == 'PAID').length;

  void _showPaymentDialog(Map<String, dynamic> fee) {
    final amountDue = double.tryParse(fee['amount_due']?.toString() ?? '0') ?? 0;
    final discount = double.tryParse(fee['discount_amount']?.toString() ?? '0') ?? 0;
    final effectiveDue = amountDue - discount;
    final amountController = TextEditingController(text: effectiveDue.toStringAsFixed(0));
    final discountController = TextEditingController(text: discount.toStringAsFixed(0));
    final discountReasonController = TextEditingController(text: fee['discount_reason']?.toString() ?? '');
    String selectedStatus = 'PAID';
    String selectedMethod = fee['payment_method']?.toString() ?? 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.payment_rounded, color: Colors.teal[700], size: 22),
              const SizedBox(width: 8),
              Text('${_monthNames[(fee['month'] ?? 1) - 1]}',
                  style: const TextStyle(fontSize: 18)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fee breakdown
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      _feeRow('Base Fee', '₹${amountDue.toStringAsFixed(0)}'),
                      _feeRow('Discount', '- ₹${discount.toStringAsFixed(0)}', color: Colors.green),
                      const Divider(),
                      _feeRow('Net Due', '₹${effectiveDue.toStringAsFixed(0)}', bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Amount Paid',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Discount
                TextField(
                  controller: discountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Discount Amount',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Discount Reason
                TextField(
                  controller: discountReasonController,
                  decoration: InputDecoration(
                    labelText: 'Discount Reason',
                    hintText: 'e.g., Sibling discount',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Payment Method
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  items: ['Cash', 'Cheque', 'UPI', 'Bank Transfer']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'Cash'),
                  decoration: InputDecoration(
                    labelText: 'Payment Method',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Status
                DropdownButtonFormField<String>(
                  value: selectedStatus,
                  items: ['PAID', 'PARTIAL']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'PAID'),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final session = await ref.read(authRepositoryProvider).getSession();
                if (session == null) return;

                await http.put(
                  Uri.parse('$BASE_URL/fees/${fee['id']}'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${session.token}',
                  },
                  body: jsonEncode({
                    'amount_paid': double.tryParse(amountController.text) ?? 0,
                    'status': selectedStatus,
                    'paid_date': DateTime.now().toIso8601String(),
                  }),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                _loadFees();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Payment recorded ✅'),
                      backgroundColor: Colors.green[700],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feeRow(String label, String value, {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(value, style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: bold ? 15 : 13,
          )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFees),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('No fee records for $_academicYear',
                          style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _generateFees,
                        icon: const Icon(Icons.add),
                        label: const Text('Generate Fee Records'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Summary bar
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.teal.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _summaryItem('Paid', '₹${_totalPaid.toStringAsFixed(0)}', Colors.green),
                          Container(width: 1, height: 30, color: Colors.grey[300]),
                          _summaryItem('Remaining', '₹${_netRemaining.toStringAsFixed(0)}', Colors.red),
                          Container(width: 1, height: 30, color: Colors.grey[300]),
                          _summaryItem('Months', '$_paidCount/12', Colors.blue),
                        ],
                      ),
                    ),

                    // Month List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _fees.length,
                        itemBuilder: (context, index) {
                          final fee = _fees[index];
                          final month = (fee['month'] ?? 1) as int;
                          final status = (fee['status'] ?? 'UNPAID') as String;
                          final amountDue = double.tryParse(fee['amount_due']?.toString() ?? '0') ?? 0;
                          final amountPaid = double.tryParse(fee['amount_paid']?.toString() ?? '0') ?? 0;
                          final discount = double.tryParse(fee['discount_amount']?.toString() ?? '0') ?? 0;
                          final netDue = amountDue - discount - amountPaid;

                          final statusColor = status == 'PAID'
                              ? Colors.green : status == 'PARTIAL'
                              ? Colors.orange : Colors.red;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.15)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: statusColor.withOpacity(0.12),
                                child: Text('$month', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                              title: Text(_monthNames[month - 1], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                              subtitle: Text(
                                'Paid: ₹${amountPaid.toStringAsFixed(0)} / Due: ₹${amountDue.toStringAsFixed(0)}'
                                '${discount > 0 ? ' (Disc: ₹${discount.toStringAsFixed(0)})' : ''}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 11),
                              ),
                              trailing: Chip(
                                label: Text(status, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.bold)),
                                backgroundColor: statusColor.withOpacity(0.1),
                                side: BorderSide.none,
                                visualDensity: VisualDensity.compact,
                              ),
                              onTap: () => _showPaymentDialog(fee),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
      ],
    );
  }

  Future<void> _generateFees() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    await http.post(
      Uri.parse('$BASE_URL/fees/generate/${widget.studentId}'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({'academic_year': _academicYear, 'monthly_amount': 5000}),
    );

    _loadFees();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fee records generated ✅'),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}
