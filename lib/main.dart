import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:async';
import 'services/sync/sync_service.dart';
import 'services/db/sqlite_service.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI for web or desktop platforms
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  final authRepo = AuthRepository();
  var session = await authRepo.getSession();

  debugPrint("BOOT - TOKEN: ${session?.token}");
  debugPrint("BOOT - ROLE: ${session?.role}");

  // Reject stale/mock tokens — real JWT tokens have 3 dot-separated parts
  if (session != null && !session.token.contains('.')) {
    debugPrint("BOOT - STALE TOKEN DETECTED! Clearing session...");
    await authRepo.clearSession();
    session = null;
  }

  runApp(
    ProviderScope(
      child: KVMErpApp(initialSession: session),
    ),
  );
}

class KVMErpApp extends ConsumerStatefulWidget {
  final AuthSession? initialSession;

  const KVMErpApp({Key? key, this.initialSession}) : super(key: key);

  @override
  ConsumerState<KVMErpApp> createState() => _KVMErpAppState();
}

class _KVMErpAppState extends ConsumerState<KVMErpApp> {
  Timer? _syncTimer;
  StreamSubscription? _syncTriggerSub;

  @override
  void initState() {
    super.initState();
    if (widget.initialSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final role = widget.initialSession!.role.toLowerCase();
        ref.read(userRoleProvider.notifier).state = UserRole.values
            .firstWhere((e) => e.name == role, orElse: () => UserRole.student);
        try {
          await ref.read(syncServiceProvider).runSyncSafe();
        } catch (e) {
          debugPrint("Boot sync warning: $e");
        }
      });
    }

    // Auto-Sync Features:
    // 1. Periodic background sync every 30 minutes
    _syncTimer = Timer.periodic(const Duration(minutes: 30), (_) {
       _triggerSync();
    });

    // 2. Real-time immediate sync whenever any local repository adds an item to the sync_queue
    _syncTriggerSub = SQLiteService.onSyncQueued.stream.listen((_) {
       _triggerSync();
    });
  }

  void _triggerSync() {
     if (mounted) {
         try {
             ref.read(syncServiceProvider).runSyncSafe();
         } catch(e) {
             debugPrint("Auto-sync trigger failed: \$e");
         }
     }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _syncTriggerSub?.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final bool hasValidSession = widget.initialSession != null &&
        widget.initialSession!.token.isNotEmpty &&
        widget.initialSession!.role.isNotEmpty;

    return MaterialApp(
      title: 'KVM ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A6CF7),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        appBarTheme: AppBarTheme(
          elevation: 0,
          scrolledUnderElevation: 1,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F9FC),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          elevation: 8,
        ),
      ),
      builder: (context, child) {
        return Container(
          color: const Color(0xFFF8F9FC),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
      home: hasValidSession ? const MainLayout() : const LoginScreen(),
    );
  }
}
