import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notices_provider.dart';
import '../../../models/notice_model.dart';
import '../../../services/db/sqlite_service.dart';
import '../../auth/repositories/auth_repository.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  final bool canCreate; // Admin, Teacher, Accountant can create
  const NoticesScreen({super.key, this.canCreate = false});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  String _userRole = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final session = await ref.read(authRepositoryProvider).getSession();
    if (session != null && mounted) {
      setState(() => _userRole = session.role);
    }
  }

  /// Returns the allowed target audiences based on current user role
  List<Map<String, String>> _getAllowedTargets() {
    if (_userRole == 'admin') {
      return [
        {'label': 'All', 'value': 'all'},
        {'label': 'Students', 'value': 'students'},
        {'label': 'Parents', 'value': 'parents'},
        {'label': 'Teachers', 'value': 'teachers'},
        {'label': 'Accountants', 'value': 'accountants'},
      ];
    } else if (_userRole == 'teacher') {
      return [
        {'label': 'Students', 'value': 'students'},
        {'label': 'Parents', 'value': 'parents'},
      ];
    } else if (_userRole == 'accountant') {
      return [
        {'label': 'Students', 'value': 'students'},
        {'label': 'Parents', 'value': 'parents'},
      ];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final noticesAsync = ref.watch(noticesListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        automaticallyImplyLeading: false,
        title: const Text('Notices & Alerts'),
      ),
      floatingActionButton: widget.canCreate
          ? FloatingActionButton.extended(
              heroTag: 'notice_fab',
              onPressed: () => _showCreateNoticeDialog(),
              icon: const Icon(Icons.add_alert_rounded),
              label: const Text('Send Notice'),
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
            )
          : null,
      body: noticesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (notices) {
          // Filter notices relevant to the user's role
          final filtered = notices.where((n) {
            if (n.isExpired) return false;
            if (n.targetAudience == 'all') return true;
            if (n.targetAudience == _userRole) return true;
            if (n.targetAudience == 'students' && _userRole == 'student') return true;
            if (n.targetAudience == 'parents' && _userRole == 'parent') return true;
            if (n.targetAudience == 'teachers' && _userRole == 'teacher') return true;
            if (n.targetAudience == 'accountants' && _userRole == 'accountant') return true;
            // Admin sees everything
            if (_userRole == 'admin') return true;
            return false;
          }).toList();

          if (filtered.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No notices yet', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                  if (widget.canCreate) ...[
                    const SizedBox(height: 8),
                    Text('Tap + to send a notice', style: TextStyle(fontSize: 13, color: Colors.grey[400])),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final notice = filtered[index];
              return _NoticeCard(
                notice: notice,
                canDelete: widget.canCreate,
                onDelete: () => _deleteNotice(notice.id),
                onTap: () => _showNoticeDetail(notice),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateNoticeDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final allowedTargets = _getAllowedTargets();
    String target = allowedTargets.isNotEmpty ? allowedTargets.first['value']! : 'all';
    bool isImportant = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Send Notice', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                _userRole == 'admin'
                    ? 'You can send to anyone'
                    : 'You can send to students & parents',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: const Icon(Icons.title, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Message *',
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Icon(Icons.message_rounded, size: 18),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Target audience — role-based
              const Text('Send to:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: allowedTargets.map((t) {
                  return _targetChip(
                    t['label']!,
                    t['value']!,
                    target,
                    (v) => setSheetState(() => target = v),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // Important toggle
              SwitchListTile(
                value: isImportant,
                onChanged: (v) => setSheetState(() => isImportant = v),
                title: const Text('Mark as Important', style: TextStyle(fontSize: 13)),
                activeColor: Colors.red,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 12),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty || descCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill title and message'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    await _saveNotice(titleCtrl.text.trim(), descCtrl.text.trim(), target, isImportant);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Notice'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _targetChip(String label, String value, String current, void Function(String) onSelect) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? Colors.deepPurple : Colors.grey.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : Colors.black87,
        )),
      ),
    );
  }

  Future<void> _saveNotice(String title, String description, String target, bool isImportant) async {
    try {
      final db = await SQLiteService().database;
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final now = DateTime.now().toIso8601String();

      // Get poster name from role
      String postedBy = _userRole[0].toUpperCase() + _userRole.substring(1);

      await db.insert('notices', {
        'id': id,
        'title': title,
        'description': description,
        'posted_by': postedBy,
        'target_audience': target,
        'posted_at': now,
        'is_important': isImportant ? 1 : 0,
        'updated_at': now,
        'device_id': 'device_01',
        'is_synced': 0,
        'is_deleted': 0,
      });

      // Queue for sync
      SQLiteService.onSyncQueued.add(null);

      ref.invalidate(noticesListProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notice sent! ✅'),
            backgroundColor: Colors.green[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send notice: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteNotice(String id) async {
    try {
      final db = await SQLiteService().database;
      await db.update('notices', {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [id]);
      ref.invalidate(noticesListProvider);
    } catch (_) {}
  }

  /// Shows full detail of a notice in a bottom sheet
  void _showNoticeDetail(NoticeModel notice) {
    final audienceColor = switch (notice.targetAudience) {
      'all' => Colors.blue,
      'students' => Colors.purple,
      'parents' => Colors.green,
      'teachers' => Colors.orange,
      'accountants' => Colors.teal,
      _ => Colors.grey,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header badges
              Row(
                children: [
                  if (notice.isImportant)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.priority_high_rounded, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text('IMPORTANT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: audienceColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: audienceColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      'To: ${notice.targetAudience.toUpperCase()}',
                      style: TextStyle(color: audienceColor, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                notice.title,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.1)),
                ),
                child: Text(
                  notice.description,
                  style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800]),
                ),
              ),
              const SizedBox(height: 20),

              // Meta info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepPurple.withOpacity(0.1)),
                ),
                child: Column(
                  children: [
                    _metaRow(Icons.person_rounded, 'Posted by', notice.postedBy),
                    const Divider(height: 16),
                    _metaRow(Icons.calendar_today_rounded, 'Date',
                        '${notice.postedAt.day}/${notice.postedAt.month}/${notice.postedAt.year} at ${notice.postedAt.hour.toString().padLeft(2, '0')}:${notice.postedAt.minute.toString().padLeft(2, '0')}'),
                    const Divider(height: 16),
                    _metaRow(Icons.groups_rounded, 'Audience', notice.targetAudience.toUpperCase()),
                    if (notice.expiresAt != null) ...[
                      const Divider(height: 16),
                      _metaRow(Icons.timer_off_rounded, 'Expires',
                          '${notice.expiresAt!.day}/${notice.expiresAt!.month}/${notice.expiresAt!.year}'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.deepPurple[300]),
        const SizedBox(width: 10),
        Text('$label: ', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Notice Card ──
class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _NoticeCard({required this.notice, required this.canDelete, required this.onDelete, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final audienceColor = switch (notice.targetAudience) {
      'all' => Colors.blue,
      'students' => Colors.purple,
      'parents' => Colors.green,
      'teachers' => Colors.orange,
      'accountants' => Colors.teal,
      _ => Colors.grey,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: notice.isImportant ? Colors.red.withOpacity(0.3) : Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (notice.isImportant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                    child: const Text('IMPORTANT', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: audienceColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notice.targetAudience.toUpperCase(),
                    style: TextStyle(color: audienceColor, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (canDelete)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(notice.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              notice.description,
              style: TextStyle(color: Colors.grey[700], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(notice.postedBy, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  '${notice.postedAt.day}/${notice.postedAt.month}/${notice.postedAt.year}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey[400]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
