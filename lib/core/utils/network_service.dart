import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../../services/sync/sync_service.dart';

final networkStateProvider = StateProvider<bool>((ref) => true); // Initially assume online

class NetworkListener {
  final Ref _ref;
  Timer? _debounce;
  Timer? _bgTimer;
  bool _previousState = true;

  NetworkListener(this._ref) {
    _ref.listen<bool>(networkStateProvider, (previous, next) {
       _previousState = previous ?? true;
       
       if (next == true && _previousState == false) {
          // Transitioned from Offline to Online - Debounce sync trigger by 3 seconds
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          _debounce = Timer(const Duration(seconds: 3), () {
             _ref.read(syncServiceProvider).runSyncSafe();
          });
       }
    });

    // Dedicated Background Sync Cycle (Headless)
    _bgTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
       final isOnline = _ref.read(networkStateProvider);
       if (isOnline) {
          await _ref.read(syncServiceProvider).runSyncSafe();
       }
    });
  }

  void dispose() {
    _debounce?.cancel();
    _bgTimer?.cancel();
  }
}

final networkListenerProvider = Provider<NetworkListener>((ref) {
  return NetworkListener(ref);
});
