import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sqflite FFI for desktop platforms (Windows/Linux/macOS)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux ||
       defaultTargetPlatform == TargetPlatform.macOS)) {
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
  @override
  void initState() {
    super.initState();
    if (widget.initialSession != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final role = widget.initialSession!.role.toLowerCase();
        ref.read(userRoleProvider.notifier).state = UserRole.values
            .firstWhere((e) => e.name == role, orElse: () => UserRole.student);
      });
    }
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
      home: hasValidSession ? const MainLayout() : const LoginScreen(),
    );
  }
}
