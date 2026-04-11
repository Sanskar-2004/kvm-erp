import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../services/sync/sync_service.dart';

class StudentFeeDetailScreen extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;
  final String classId;

  const StudentFeeDetailScreen({
    Key? key,
    required this.studentId,
    required this.studentName,
    required this.classId,
  }) : super(key: key);

  @override
  ConsumerState<StudentFeeDetailScreen> createState() => _StudentFeeDetailScreenState();
}

class _StudentFeeDetailScreenState extends ConsumerState<StudentFeeDetailScreen> {
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _academicYear = '2026-2027';

  final List<String> _yearOptions = AcademicUtils.academicYears;

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
          _fees = List<Map<String, dynamic>>.from(data['fees'] ?? []);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Load fees error: $e');
    }
  }

  double get _totalDue => _fees.fold(0, (s, f) => s + _p(f['amount_due']));
  double get _totalPaid => _fees.fold(0, (s, f) => s + _p(f['amount_paid']));
  double get _totalDiscount => _fees.fold(0, (s, f) => s + _p(f['discount_amount']));
  double get _netRemaining => _totalDue - _totalPaid - _totalDiscount;
  int get _paidCount => _fees.where((f) => f['status'] == 'PAID').length;
  int get _unpaidCount => _fees.where((f) => f['status'] == 'UNPAID').length;
  int get _partialCount => _fees.where((f) => f['status'] == 'PARTIAL').length;

  double _p(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  Future<void> _sendAlert() async {
    final msgController = TextEditingController(
      text: 'Fee payment reminder: Fee for ${widget.studentName} (Class ${widget.classId}) is overdue. '
          'Remaining: ₹${_netRemaining.toStringAsFixed(0)}. Please clear dues at the earliest.',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.notifications_active, color: Colors.orange[700], size: 22),
          const SizedBox(width: 8),
          const Text('Alert Parent', style: TextStyle(fontSize: 17)),
        ]),
        content: TextField(
          controller: msgController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Alert Message',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.send, size: 16),
            label: const Text('Send Alert'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    await http.post(
      Uri.parse('$BASE_URL/fees/alerts'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${session.token}',
      },
      body: jsonEncode({
        'user_id': widget.studentId,
        'message': msgController.text,
      }),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text('Alert sent to ${widget.studentName}\'s parent'),
        ]),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _showPaymentDialog(Map<String, dynamic> fee) {
    final amountDue = _p(fee['amount_due']);
    final discount = _p(fee['discount_amount']);
    final effectiveDue = amountDue - discount;
    final amountController = TextEditingController(text: effectiveDue.toStringAsFixed(0));
    String selectedStatus = 'PAID';
    String selectedMethod = fee['payment_method']?.toString() ?? 'Cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.payment_rounded, color: Colors.teal[700], size: 22),
            const SizedBox(width: 8),
            Text('${_monthNames[(fee['month'] ?? 1) - 1]}', style: const TextStyle(fontSize: 18)),
          ]),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  _feeRow('Base Fee', '₹${amountDue.toStringAsFixed(0)}'),
                  _feeRow('Discount', '- ₹${discount.toStringAsFixed(0)}', color: Colors.green),
                  const Divider(),
                  _feeRow('Net Due', '₹${effectiveDue.toStringAsFixed(0)}', bold: true),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount Paid', prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                items: ['Cash', 'Cheque', 'UPI', 'Bank Transfer']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setDialogState(() => selectedMethod = v ?? 'Cash'),
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                items: ['PAID', 'PARTIAL']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setDialogState(() => selectedStatus = v ?? 'PAID'),
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), isDense: true,
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () async {
                final session = await ref.read(authRepositoryProvider).getSession();
                if (session == null) return;
                await http.put(
                  Uri.parse('$BASE_URL/fees/${fee['id']}'),
                  headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${session.token}'},
                  body: jsonEncode({
                    'amount_paid': double.tryParse(amountController.text) ?? 0,
                    'status': selectedStatus,
                    'paid_date': DateTime.now().toIso8601String(),
                  }),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _loadFees();
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Save'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal, foregroundColor: Colors.white,
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
          DropdownButton<String>(
            value: _academicYear,
            underline: const SizedBox(),
            icon: const Icon(Icons.calendar_today, size: 16),
            items: _yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y, style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _academicYear = v;
                  _isLoading = true;
                });
                _loadFees();
              }
            },
          ),
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
                      Text('No fee records for $_academicYear', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _generateFees,
                        icon: const Icon(Icons.add),
                        label: const Text('Generate Fee Records'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Student info header
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal[700]!, Colors.teal[400]!],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(children: [
                        Row(children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.white24,
                            child: Text(widget.studentName[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(widget.studentName,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                              Text('Class ${widget.classId} • $_academicYear',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
                            ]),
                          ),
                          IconButton(
                            onPressed: _netRemaining > 0 ? _sendAlert : null,
                            icon: Icon(Icons.notifications_active_rounded,
                                color: _netRemaining > 0 ? Colors.orange[300] : Colors.white30, size: 26),
                            tooltip: 'Alert Parent',
                          ),
                        ]),
                        const SizedBox(height: 16),
                        // Summary stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _summaryItem('Total Due', '₹${_totalDue.toStringAsFixed(0)}', Colors.white),
                            Container(width: 1, height: 30, color: Colors.white30),
                            _summaryItem('Paid', '₹${_totalPaid.toStringAsFixed(0)}', Colors.greenAccent),
                            Container(width: 1, height: 30, color: Colors.white30),
                            _summaryItem('Remaining', '₹${_netRemaining.toStringAsFixed(0)}',
                                _netRemaining > 0 ? Colors.orangeAccent : Colors.greenAccent),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Status chips
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _statusChip('$_paidCount Paid', Colors.green),
                          const SizedBox(width: 8),
                          _statusChip('$_unpaidCount Unpaid', Colors.red),
                          const SizedBox(width: 8),
                          _statusChip('$_partialCount Partial', Colors.orange),
                        ]),
                      ]),
                    ),

                    // Month-wise fee list
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Month-wise Breakdown',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.grey[700])),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _fees.length,
                        itemBuilder: (context, index) {
                          final fee = _fees[index];
                          final month = (fee['month'] ?? 1) as int;
                          final status = (fee['status'] ?? 'UNPAID') as String;
                          final amountDue = _p(fee['amount_due']);
                          final amountPaid = _p(fee['amount_paid']);
                          final discount = _p(fee['discount_amount']);
                          final paidDate = fee['paid_date']?.toString();

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
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Due: ₹${amountDue.toStringAsFixed(0)} • Paid: ₹${amountPaid.toStringAsFixed(0)}'
                                    '${discount > 0 ? ' • Disc: ₹${discount.toStringAsFixed(0)}' : ''}',
                                    style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                  ),
                                  if (paidDate != null && status != 'UNPAID')
                                    Text('Paid on: ${paidDate.split('T').first}',
                                        style: TextStyle(color: Colors.green[600], fontSize: 10, fontWeight: FontWeight.w500)),
                                ],
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
    return Column(children: [
      Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ]);
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _generateFees() async {
    final amountController = TextEditingController(text: '5000');
    int startMonth = 4; // Start of Indian academic year
    int endMonth = 3;   // Standard end logic handled by dialog

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Generate Fee Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Monthly Amount',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Academic Year', style: TextStyle(fontSize: 12, color: Colors.grey)),
              DropdownButton<String>(
                value: _academicYear,
                isExpanded: true,
                items: _yearOptions.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => _academicYear = v);
                    setState(() => _academicYear = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                   Expanded(
                     child: DropdownButtonFormField<int>(
                       value: startMonth,
                       decoration: const InputDecoration(labelText: 'From Month', isDense: true),
                       items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                       onChanged: (v) => setDialogState(() => startMonth = v ?? startMonth),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Expanded(
                     child: DropdownButtonFormField<int>(
                       value: endMonth == 3 ? 12 : endMonth, // simplified for dialog
                       decoration: const InputDecoration(labelText: 'To Month', isDense: true),
                       items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthNames[i]))),
                       onChanged: (v) => setDialogState(() => endMonth = v ?? endMonth),
                     ),
                   ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              child: const Text('Generate', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    try {
      final response = await http.post(
        Uri.parse('$BASE_URL/fees/generate/${widget.studentId}'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${session.token}'},
        body: jsonEncode({
          'academic_year': _academicYear, 
          'monthly_amount': double.tryParse(amountController.text) ?? 5000,
          'start_month': startMonth,
          'end_month': endMonth,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Trigger a background sync pull immediately so local SQLite has the new rows
        await ref.read(syncServiceProvider).runSyncSafe();
        _loadFees();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(data['message'] ?? 'Fee records generated and synced ✅'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (e) {
      debugPrint('Generation error: $e');
      setState(() => _isLoading = false);
    }
  }
}
