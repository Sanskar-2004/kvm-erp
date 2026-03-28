import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/app_constants.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/utils/academic_utils.dart';

class ParentDashboard extends ConsumerStatefulWidget {
  const ParentDashboard({Key? key}) : super(key: key);

  @override
  ConsumerState<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends ConsumerState<ParentDashboard> {
  List<Map<String, dynamic>> _children = [];
  int _selectedChildIndex = 0;
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;

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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final children = List<Map<String, dynamic>>.from(data['children'] ?? []);
        setState(() => _children = children);
        if (children.isNotEmpty) {
          _loadStudentSummary(children[0]['id']);
        } else {
          // No linked children — show demo data
          setState(() => _isLoading = false);
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
      final response = await http.get(
        Uri.parse('$BASE_URL/parent/student-summary/$studentId'),
        headers: {'Authorization': 'Bearer ${session.token}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _summary = data['data'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Summary error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadChildren,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text("My Child's Dashboard",
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Pull down to refresh', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.green : Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.child_care_rounded, size: 18,
                                  color: isSelected ? Colors.white : Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                child['name'] ?? 'Child ${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

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
    final pct = double.tryParse(_summary['attendance']?['percentage']?.toString() ?? '0') ?? 0;
    if (pct >= 90) return 'Excellent';
    if (pct >= 75) return 'Good';
    if (pct >= 50) return 'Needs Improvement';
    return 'Critical';
  }

  String _getFeeSummary() {
    final due = double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ?? 0;
    final remaining = due - paid;
    if (remaining <= 0) return 'All Clear';
    return '₹${remaining.toStringAsFixed(0)} Due';
  }

  Color _getFeeColor() {
    final due = double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ?? 0;
    return (due - paid) > 0 ? Colors.red : Colors.green;
  }

  String _getFeeStatus() {
    final due = double.tryParse(_summary['fees']?['total_due']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(_summary['fees']?['total_paid']?.toString() ?? '0') ?? 0;
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Attendance Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStat('Total Days', '${att['total'] ?? 0}', Colors.blue),
                _detailStat('Present', '${att['present'] ?? 0}', Colors.green),
                _detailStat('Absent', '${(att['total'] ?? 0) - (att['present'] ?? 0)}', Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (double.tryParse(att['percentage']?.toString() ?? '0') ?? 0) / 100,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.green),
              ),
            ),
            const SizedBox(height: 8),
            Text('${att['percentage'] ?? 0}% Attendance Rate',
                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])),
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
            const Text('Fee Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _detailStat('Total Due', '₹${due.toStringAsFixed(0)}', Colors.blue),
                _detailStat('Paid', '₹${paid.toStringAsFixed(0)}', Colors.green),
                _detailStat('Remaining', '₹${(due - paid).toStringAsFixed(0)}', Colors.red),
              ],
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: due > 0 ? (paid / due).clamp(0, 1) : 0,
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(paid >= due ? Colors.green : Colors.orange),
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
              const Text('Report Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: marks.isEmpty
                    ? Center(child: Text('No results yet', style: TextStyle(color: Colors.grey[400])))
                    : ListView.builder(
                        controller: scrollCtrl,
                        itemCount: marks.length,
                        itemBuilder: (ctx, i) {
                          final m = marks[i];
                          final obtained = double.tryParse(m['marks_obtained']?.toString() ?? '0') ?? 0;
                          final total = double.tryParse(m['total_marks']?.toString() ?? '100') ?? 100;
                          final pct = total > 0 ? (obtained / total) * 100 : 0;
                          final grade = AcademicUtils.generateGrade(pct.toDouble());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.withOpacity(0.12)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m['subject']?.toString() ?? 'Subject',
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                      Text('${m['exam_type'] ?? ''} • Rank: ${m['class_rank'] ?? '-'}',
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${obtained.toStringAsFixed(0)}/${total.toStringAsFixed(0)}',
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text('Grade: $grade',
                                        style: TextStyle(fontSize: 12, color: Colors.blue[700], fontWeight: FontWeight.w600)),
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
              const Text('Notices & Alerts', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: alerts.isEmpty
                    ? Center(child: Text('No alerts', style: TextStyle(color: Colors.grey[400])))
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
                              color: isRead ? Colors.grey.withOpacity(0.04) : Colors.orange.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isRead ? Colors.grey.withOpacity(0.1) : Colors.orange.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isRead ? Icons.check_circle_outline : Icons.notifications_active_rounded,
                                  color: isRead ? Colors.grey : Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(alert['message']?.toString() ?? '',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                          )),
                                      const SizedBox(height: 4),
                                      Text(alert['created_at']?.toString() ?? '',
                                          style: TextStyle(fontSize: 10, color: Colors.grey[400])),
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
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
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
    required this.title, required this.value, required this.status,
    required this.icon, required this.color, required this.onTap,
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
                  Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 3),
                  Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Column(
              children: [
                Chip(
                  label: Text(status, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide.none,
                  visualDensity: VisualDensity.compact,
                ),
                Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.4), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
