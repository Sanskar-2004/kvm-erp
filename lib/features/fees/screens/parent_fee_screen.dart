import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/academic_utils.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../services/db/sqlite_service.dart';
import '../../../services/sync/sync_service.dart';

/// Parent fee screen — shows expandable fee cards for each child, filtered by year
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
  String _selectedYear = AcademicUtils.academicYears.last;

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
      // 1. Get children list — try API first, fall back to local phone matching
      final childResp = await http.get(
        Uri.parse('$BASE_URL/parent/children/${session.userId}'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      ).timeout(const Duration(seconds: 8));

      List<Map<String, dynamic>> children = [];
      if (childResp.statusCode == 200) {
        final data = jsonDecode(childResp.body);
        children = List<Map<String, dynamic>>.from(data['children'] ?? []);
      }

      // If no children linked remotely, match by phone locally
      if (children.isEmpty) {
        try {
           await ref.read(syncServiceProvider).runSyncSafe();
        } catch (_) {}

        final db = await SQLiteService().database;
        
        final userRows = await db.query('users', where: 'id = ?', whereArgs: [session.userId]);
        String? parentContact;
        if (userRows.isNotEmpty) {
           parentContact = userRows.first['username']?.toString();
           if (parentContact == null || parentContact.isEmpty) {
               parentContact = userRows.first['email']?.toString();
           }
        }

        if (parentContact != null && parentContact.trim().isNotEmpty) {
           final matchedStudents = await db.query(
              'students', 
              where: 'is_deleted = 0 AND (parent_phone = ? OR phone = ? OR email = ?)', 
              whereArgs: [parentContact, parentContact, parentContact]
           );
           if (matchedStudents.isNotEmpty) {
              children = matchedStudents.toList();
           }
        }
      }

      setState(() => _children = children);

      // 2. Fetch fee summary for each child from LOCAL SQLite, filtered by year
      _childFees = {};
      for (final child in children) {
        final childId = child['id']?.toString() ?? '';
        if (childId.isEmpty) continue;

        try {
          final sData = await SQLiteService().getStudentSummary(
            childId,
            academicYear: _selectedYear,
          );
          _childFees[childId] = sData['fees'] ?? {};
        } catch (_) {}
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
                    // Header with year selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Children's Fees",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.teal.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.teal.withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedYear,
                              icon: const Icon(Icons.calendar_today, size: 14, color: Colors.teal),
                              style: const TextStyle(fontSize: 12, color: Colors.teal, fontWeight: FontWeight.bold),
                              items: AcademicUtils.academicYears
                                  .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedYear = v);
                                  _loadChildrenFees();
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Tap any child to expand • $_selectedYear',
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
                              // Header (always visible)
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
                                            Text('Class $classId • $_selectedYear',
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
                                                    ? totalDue > 0 ? 'PAID' : 'NO FEE'
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

                              // Expanded Details
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
