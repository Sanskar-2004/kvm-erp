import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/sync/sync_service.dart';

enum SyncState { idle, syncing, success, error }

// Pull deeply persisted timestamp across physical app reboots
final lastSyncTimeProvider = FutureProvider.autoDispose<DateTime?>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final timestamp = prefs.getInt('last_sync_at');
  if (timestamp == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(timestamp);
});

final syncStateProvider = StateProvider<SyncState>((ref) => SyncState.idle);

class SyncStatusBadge extends ConsumerWidget {
  const SyncStatusBadge({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncStateProvider);
    final lastSynced = ref.watch(lastSyncTimeProvider).value;
    final pendingCount = ref.watch(pendingCountProvider).value ?? 0;
    final failedCount = ref.watch(failedCountProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: syncState == SyncState.syncing 
            ? null 
            : () async {
                // If there are failures, explicitly resurrect Dead Items
                if (failedCount > 0) {
                   ref.read(syncStateProvider.notifier).state = SyncState.syncing;
                   await ref.read(syncServiceProvider).retryFailedQueue();
                   ref.invalidate(failedCountProvider);
                   ref.invalidate(pendingCountProvider);
                   ref.read(syncStateProvider.notifier).state = SyncState.idle;
                } else {
                   ref.read(syncStateProvider.notifier).state = SyncState.syncing;
                   try {
                     await ref.read(syncServiceProvider).runSyncSafe();
                     
                     // Persist Timestamp physically across OS loads
                     final prefs = await SharedPreferences.getInstance();
                     await prefs.setInt('last_sync_at', DateTime.now().millisecondsSinceEpoch);
                     
                     ref.read(syncStateProvider.notifier).state = SyncState.success;
                     
                     ref.invalidate(lastSyncTimeProvider);
                     ref.invalidate(pendingCountProvider);
                     ref.invalidate(failedCountProvider);
                     
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Sync completed successfully!')),
                       );
                     }
                   } catch (e) {
                     ref.read(syncStateProvider.notifier).state = SyncState.error;
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
                       );
                     }
                   }
                }
              },
        child: Row(
          children: [
             Icon(
               syncState == SyncState.syncing 
                  ? Icons.sync 
                  : failedCount > 0
                      ? Icons.warning_amber_rounded
                      : pendingCount > 0 
                          ? Icons.cloud_upload
                          : Icons.cloud_done,
               size: 20,
               color: failedCount > 0 
                  ? Colors.orange 
                  : syncState == SyncState.syncing 
                      ? Colors.white 
                      : (pendingCount == 0 ? Colors.green : Colors.blue),
             ),
             const SizedBox(width: 8),
             if (syncState == SyncState.syncing)
                const SizedBox(
                  width: 12, height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
             else 
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Sync: $pendingCount Pending | $failedCount Failed",
                      style: TextStyle(
                         fontSize: 12, 
                         fontWeight: FontWeight.bold,
                         color: failedCount > 0 ? Colors.orange : Colors.white
                      ),
                    ),
                    if (lastSynced != null)
                      Text(
                        "Last synced: ${lastSynced.hour.toString().padLeft(2, '0')}:${lastSynced.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 9, color: Colors.white70),
                      )
                  ],
                )
          ],
        ),
      ),
    );
  }
}
