import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../fees/providers/fee_analytics_provider.dart';

class AdminFinanceScreen extends ConsumerStatefulWidget {
  const AdminFinanceScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends ConsumerState<AdminFinanceScreen> {
  Map<String, dynamic> _yearly = {};
  List<Map<String, dynamic>> _recentTransactions = [];
  int _unpaidCount = 0;
  bool _isLoading = true;

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
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) return;

    try {
      // By using ref.refresh, we FORCE the provider to bypass cache and query SQLite again, 
      final finance = await ref.refresh(feeAnalyticsProvider(null).future) as Map<String, dynamic>;

      setState(() {
        _yearly = {
          'total_paid': finance['collected'],
          'total_pending': finance['pending'],
          'total_due': finance['expected']
        };
        _recentTransactions =
            List<Map<String, dynamic>>.from(finance['transactions'] ?? []);
        _unpaidCount = finance['due_students'] ?? 0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Finance load error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Overview'),
        actions: [
          IconButton(
              icon: const Icon(Icons.refresh), onPressed: _loadFinanceData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadFinanceData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Yearly Totals Cards ──
                    Row(
                      children: [
                        Expanded(
                            child: _totalCard(
                          'Total Collected',
                          '₹${_parseNum(_yearly['total_paid']).toStringAsFixed(0)}',
                          Icons.trending_up_rounded,
                          Colors.green,
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _totalCard(
                          'Total Pending',
                          '₹${_parseNum(_yearly['total_pending']).toStringAsFixed(0)}',
                          Icons.trending_down_rounded,
                          Colors.red,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _totalCard(
                          'Total Expected',
                          '₹${_parseNum(_yearly['total_due']).toStringAsFixed(0)}',
                          Icons.account_balance_rounded,
                          Colors.blue,
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _totalCard(
                          'Unpaid Students',
                          '$_unpaidCount',
                          Icons.person_off_rounded,
                          Colors.orange,
                        )),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Collection Progress ──
                    _buildProgressBar(),
                    const SizedBox(height: 24),

                    // ── Recent Transactions ──
                    Text('Recent 10 Transactions',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    if (_recentTransactions.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_rounded,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            Text('No transactions yet',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_recentTransactions.length, (index) {
                        final txn = _recentTransactions[index];
                        final amount = _parseNum(txn['amount_paid']);
                        final month =
                            txn['month'] is int ? txn['month'] as int : 0;
                        final method =
                            txn['payment_method']?.toString() ?? 'N/A';
                        final status = txn['status']?.toString() ?? 'PAID';

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
                          child: Row(
                            children: [
                              // Index
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

                              // Details
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
                                    Row(
                                      children: [
                                        Icon(methodIcon,
                                            size: 13, color: Colors.grey[400]),
                                        const SizedBox(width: 4),
                                        Text(method,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey[500])),
                                        const SizedBox(width: 8),
                                        if (month > 0 && month <= 12)
                                          Text('• ${_monthNames[month - 1]}',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[500])),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Amount
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('₹${amount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                          fontSize: 15)),
                                  Chip(
                                    label: Text(status,
                                        style: const TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold)),
                                    backgroundColor:
                                        Colors.green.withOpacity(0.1),
                                    side: BorderSide.none,
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(
                                        horizontal: 6),
                                  ),
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

  Widget _totalCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final totalDue = _parseNum(_yearly['total_due']);
    final totalPaid = _parseNum(_yearly['total_paid']);
    final progress =
        totalDue > 0 ? (totalPaid / totalDue).clamp(0.0, 1.0) : 0.0;
    final percent = (progress * 100).toStringAsFixed(1);

    return Container(
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
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text('$percent%',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.blue[700])),
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
    );
  }

  double _parseNum(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
