import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/sync/sync_service.dart';
import '../utils/network_service.dart';

enum SyncState { idle, syncing, success, error }

final lastSyncTimeProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final timestamp = prefs.getInt('last_sync_at');
  if (timestamp == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(timestamp);
});

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({Key? key}) : super(key: key);

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final lastSynced = ref.watch(lastSyncTimeProvider).value;
    final isOnline = ref.watch(networkStateProvider);
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;
    final failedCount = ref.watch(failedCountProvider).value ?? 0;

    // Determine visual state
    IconData icon;
    Color iconColor;
    String label;
    Color? bgColor;

    if (!isOnline) {
      // OFFLINE
      icon = Icons.cloud_off_rounded;
      iconColor = Colors.grey;
      label = 'Offline';
      bgColor = Colors.grey.withOpacity(0.15);
    } else if (syncState == SyncState.syncing) {
      // SYNCING
      icon = Icons.sync_rounded;
      iconColor = Colors.blue;
      label = 'Syncing...';
      bgColor = Colors.blue.withOpacity(0.1);
    } else if (failedCount > 0) {
      // HAS FAILURES
      icon = Icons.error_outline_rounded;
      iconColor = Colors.orange;
      label = '$failedCount Failed';
      bgColor = Colors.orange.withOpacity(0.1);
    } else if (pendingCount > 0) {
      // HAS PENDING
      icon = Icons.cloud_upload_rounded;
      iconColor = Colors.blue;
      label = '$pendingCount Pending';
      bgColor = Colors.blue.withOpacity(0.1);
    } else {
      // ALL SYNCED
      icon = Icons.cloud_done_rounded;
      iconColor = Colors.green;
      label = lastSynced != null ? _timeAgo(lastSynced) : 'Synced';
      bgColor = Colors.green.withOpacity(0.1);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: syncState == SyncState.syncing
            ? null
            : () => _triggerSync(ref, context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (syncState == SyncState.syncing)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                )
              else
                Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _triggerSync(WidgetRef ref, BuildContext context) async {
    final failedCount = ref.read(failedCountProvider).value ?? 0;

    ref.read(syncStateProvider.notifier).state = SyncState.syncing;

    try {
      if (failedCount > 0) {
        await ref.read(syncServiceProvider).retryFailedQueue();
      } else {
        await ref.read(syncServiceProvider).runSyncSafe();
      }

      if (!context.mounted) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_sync_at', DateTime.now().millisecondsSinceEpoch);

      ref.read(syncStateProvider.notifier).state = SyncState.success;
      ref.invalidate(lastSyncTimeProvider);
      ref.invalidate(pendingCountProvider);
      ref.invalidate(failedCountProvider);

      // Auto-reset to idle after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (ref.exists(syncStateProvider)) {
          ref.read(syncStateProvider.notifier).state = SyncState.idle;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sync completed'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ref.read(syncStateProvider.notifier).state = SyncState.error;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Sync failed: ${e.toString().substring(0, 50)}')),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      // Reset to idle after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (ref.exists(syncStateProvider)) {
          ref.read(syncStateProvider.notifier).state = SyncState.idle;
        }
      });
    }
  }
}
