import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/widgets/main_layout.dart';
import 'features/auth/repositories/auth_repository.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final authRepo = AuthRepository();
  var session = await authRepo.getSession();

  // DEBUGGING: Check console to verify session state on boot
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
    // Strict routing: no token or no role = always LoginScreen
    final bool hasValidSession = widget.initialSession != null &&
        widget.initialSession!.token.isNotEmpty &&
        widget.initialSession!.role.isNotEmpty;

    return MaterialApp(
      title: 'KVM ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: hasValidSession ? const MainLayout() : const LoginScreen(),
    );
  }
}
