import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';

/// Parent fee screen — shows expandable fee cards for each child
class ParentFeeScreen extends ConsumerStatefulWidget {
  const ParentFeeScreen({super.key});

  @override
  ConsumerState<ParentFeeScreen> createState() => _ParentFeeScreenState();
}

class _ParentFeeScreenState extends ConsumerState<ParentFeeScreen> {
  List<Map<String, dynamic>> _children = [];
  Map<String, Map<String, dynamic>> _childFees = {}; // childId -> fee summary
  Set<String> _expandedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChildrenFees();
  }

  Future<void> _loadChildrenFees() async {
    setState(() => _isLoading = true);
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Get children list
      final childResp = await http.get(
        Uri.parse('$BASE_URL/parent/children/${session.userId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (childResp.statusCode == 200) {
        final data = jsonDecode(childResp.body);
        final children =
            List<Map<String, dynamic>>.from(data['children'] ?? []);
        setState(() => _children = children);

        // 2. Fetch fee summary for each child
        for (final child in children) {
          final childId = child['id']?.toString() ?? '';
          if (childId.isEmpty) continue;

          try {
            final summaryResp = await http.get(
              Uri.parse('$BASE_URL/parent/student-summary/$childId'),
              headers: {'Authorization': 'Bearer ${session.token}'},
            );
            if (summaryResp.statusCode == 200) {
              final sData = jsonDecode(summaryResp.body)['data'] ?? {};
              setState(() {
                _childFees[childId] = sData['fees'] ?? {};
              });
            }
          } catch (_) {}
        }

        // If no children linked, try to find demo student
        if (children.isEmpty) {
          final pullResp = await http.get(
            Uri.parse('$BASE_URL/sync/pull?lastSync=2000-01-01T00:00:00.000Z'),
            headers: {'Authorization': 'Bearer ${session.token}'},
          );
          if (pullResp.statusCode == 200) {
            final pullData = jsonDecode(pullResp.body);
            final students = List<Map<String, dynamic>>.from(
                pullData['data']['students'] ?? []);
            if (students.isNotEmpty) {
              setState(() => _children = [students.first]);
            }
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Load parent fees error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadChildrenFees,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Children's Fees",
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Tap any child to expand details',
                        style:
                            TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 16),
                    if (_children.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(40),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            Icon(Icons.family_restroom_rounded,
                                size: 56, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('No children linked',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 16)),
                            const SizedBox(height: 8),
                            Text('Ask admin to link your children',
                                style: TextStyle(
                                    color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_children.length, (i) {
                        final child = _children[i];
                        final childId = child['id']?.toString() ?? '';
                        final name =
                            child['name']?.toString() ?? 'Child ${i + 1}';
                        final classId = child['class_id']?.toString() ?? '-';
                        final fees = _childFees[childId] ?? {};

                        final totalDue = double.tryParse(
                                fees['total_due']?.toString() ?? '0') ??
                            0;
                        final totalPaid = double.tryParse(
                                fees['total_paid']?.toString() ?? '0') ??
                            0;
                        final remaining = totalDue - totalPaid;
                        final isExpanded = _expandedIds.contains(childId);
                        final isPaid = remaining <= 0;
                        final paidPct = totalDue > 0
                            ? (totalPaid / totalDue).clamp(0.0, 1.0)
                            : 0.0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: isPaid
                                    ? Colors.green.withOpacity(0.2)
                                    : Colors.red.withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            children: [
                              // ── Header (always visible) ──
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    if (isExpanded) {
                                      _expandedIds.remove(childId);
                                    } else {
                                      _expandedIds.add(childId);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: isPaid
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.red.withOpacity(0.1),
                                        child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 18,
                                                color: isPaid
                                                    ? Colors.green[700]
                                                    : Colors.red[700])),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(name,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16)),
                                            const SizedBox(height: 2),
                                            Text('Class $classId',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[500])),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                              '₹${totalDue.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14)),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPaid
                                                  ? Colors.green
                                                      .withOpacity(0.1)
                                                  : Colors.red.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                                isPaid
                                                    ? 'PAID'
                                                    : '₹${remaining.toStringAsFixed(0)} due',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isPaid
                                                        ? Colors.green
                                                        : Colors.red)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                          isExpanded
                                              ? Icons.keyboard_arrow_up_rounded
                                              : Icons
                                                  .keyboard_arrow_down_rounded,
                                          color: Colors.grey[400]),
                                    ],
                                  ),
                                ),
                              ),

                              // ── Expanded Details ──
                              if (isExpanded)
                                Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Column(
                                    children: [
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      // Progress bar
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Payment Progress',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600])),
                                          Text(
                                              '${(paidPct * 100).toStringAsFixed(0)}%',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: isPaid
                                                      ? Colors.green
                                                      : Colors.orange)),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: paidPct,
                                          minHeight: 8,
                                          backgroundColor: Colors.grey[200],
                                          valueColor: AlwaysStoppedAnimation(
                                              isPaid
                                                  ? Colors.green
                                                  : Colors.orange),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      // Stats
                                      Row(
                                        children: [
                                          _statBox(
                                              'Total',
                                              '₹${totalDue.toStringAsFixed(0)}',
                                              Colors.blue),
                                          const SizedBox(width: 10),
                                          _statBox(
                                              'Paid',
                                              '₹${totalPaid.toStringAsFixed(0)}',
                                              Colors.green),
                                          const SizedBox(width: 10),
                                          _statBox(
                                              'Pending',
                                              '₹${remaining.toStringAsFixed(0)}',
                                              Colors.red),
                                        ],
                                      ),
                                    ],
                                  ),
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

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
