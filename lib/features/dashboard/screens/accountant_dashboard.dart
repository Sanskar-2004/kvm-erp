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

class _AccountantDashboardState extends ConsumerState<AccountantDashboard> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
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
        setState(() => _students = students);
      }
    } catch (e) {
      debugPrint('Load students error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStudents {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) return _students;
    return _students.where((s) => 
      (s['name'] ?? '').toString().toLowerCase().contains(query) ||
      (s['class_id'] ?? '').toString().toLowerCase().contains(query)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fee Management',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Search student by name or class...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStudents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text('No students found', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.teal.withOpacity(0.1),
                                child: Text(
                                  (student['name'] ?? 'S')[0].toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal),
                                ),
                              ),
                              title: Text(student['name'] ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('Class: ${student['class_id'] ?? '-'}'),
                              trailing: const Icon(Icons.chevron_right, color: Colors.teal),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FeeCalendarScreen(
                                      studentId: student['id'],
                                      studentName: student['name'] ?? 'Unknown',
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Fee Calendar Screen (12-Month View) ──
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

  void _showPaymentDialog(Map<String, dynamic> fee) {
    final amountController = TextEditingController(text: fee['amount_due']?.toString() ?? '0');
    String selectedStatus = 'PAID';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Record Payment — ${_monthNames[(fee['month'] ?? 1) - 1]}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Due: ₹${fee['amount_due']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Paid (₹)', prefixText: '₹ '),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedStatus,
              items: ['PAID', 'PARTIAL'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => selectedStatus = v ?? 'PAID',
              decoration: const InputDecoration(labelText: 'Status'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
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
              _loadFees(); // Refresh
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment recorded ✅'), backgroundColor: Colors.green),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Save Payment'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFees,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _fees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No fee records for $_academicYear',
                          style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _generateFees,
                        icon: const Icon(Icons.add),
                        label: const Text('Generate Fee Records'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _fees.length,
                  itemBuilder: (context, index) {
                    final fee = _fees[index];
                    final month = (fee['month'] ?? 1) as int;
                    final status = (fee['status'] ?? 'UNPAID') as String;
                    final amountDue = (fee['amount_due'] ?? 0).toString();
                    final amountPaid = (fee['amount_paid'] ?? 0).toString();

                    final statusColor = status == 'PAID'
                        ? Colors.green
                        : status == 'PARTIAL'
                            ? Colors.orange
                            : Colors.red;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: statusColor.withOpacity(0.2)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: statusColor.withOpacity(0.15),
                          child: Text('${month}', style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(_monthNames[month - 1], style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Paid: ₹$amountPaid / Due: ₹$amountDue',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        trailing: Chip(
                          label: Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                          backgroundColor: statusColor.withOpacity(0.1),
                          side: BorderSide.none,
                        ),
                        onTap: () => _showPaymentDialog(fee),
                      ),
                    );
                  },
                ),
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
        const SnackBar(content: Text('Fee records generated ✅'), backgroundColor: Colors.green),
      );
    }
  }
}
